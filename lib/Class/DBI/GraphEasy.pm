package Class::DBI::GraphEasy;

=head1 NAME

Class::DBI::GraphEasy - use Graph::Easy to graph Class::DBI classes easily.

=head1 SYNOPSIS

    my $graph = Class::DBI::GraphEasy->new (classes => ['Music::Artist','Music::CD'], prettify => 1, colorize => 1, show_columns => 1, no_recursion => 0); #returns a Graph::Easy object
	print $graph->as_html_file(); #render $graph as html for rapid graphing
	my $graphviz = $graph->as_graphviz(); #render as graphviz for best results

=head1 DESCRIPTION

This module integrates Class::DBI and Graph::Easy. It is designed to easily generate diagrams to illustrate the given Class::DBI classes. By default, it traverses both 'has a' and 'has many' relationships to discovery foreign classes recusively until not further relationships are found.

=cut

use vars qw($VERSION @EXPORT);
use Exporter;
use vars qw(@ISA @EXPORT $VERSION);
@ISA = qw(Exporter); 
@EXPORT = qw(new);

use strict;
use warnings;
use Graph::Easy;

our $VERSION = 0.01;

sub new
{
	my $self = shift;
	my %args = (@_);
    return unless ref $args{classes} eq 'ARRAY';	
	my $graph = Graph::Easy->new();
	$graph->set_attribute('fill','white');
	$graph->set_attribute('flow' => $args{flow}) if $args{flow};
	return _graph_it($graph, $args{classes}, $args{prettify}, $args{colorize}, $args{show_columns}, $args{no_recursion}, $args{arrow_style});
}

sub _graph_it
{
	my $graph = shift;
	my $classes = shift;
	my $prettify = shift;
	my $colorize = shift;
	my $show_columns = shift;
	my $no_recursion = shift;
	my $arrow_style = shift;
	
	foreach my $class (@{$classes})
	{
		
		if($class->isa("Class::DBI")) #check if it's a Class::DBI class whether 
		{
			my $class_name = _prettify($class, $prettify);
			my $foreign_keys;
			foreach my $rel (keys %{$class->meta_info->{'has_a'}})
			{
				my $foreign_class = $class->meta_info->{'has_a'}->{$rel}->{foreign_class};
				$foreign_keys->{$class->meta_info->{'has_a'}->{$rel}->{accessor}->{name}} = undef;
				my $foreign_class_name =  _prettify($foreign_class, $prettify);
				if ($foreign_class->isa("Class::DBI")) #is the foreign class a Class::DBI class too?
				{
					unless ($graph->edge("$class", "$foreign_class")) #this is prevent duplicated edges.
					{
						my ($class_node, $foreign_class_node, $edge) = $graph->add_edge("$class", "$foreign_class");
						$edge->set_attribute('arrowstyle', $arrow_style) if $arrow_style; 
						$edge->set_attribute('color','grey') if $colorize;
						$graph = _graph_it($graph, [$foreign_class], $prettify, $colorize, $show_columns, $no_recursion, $arrow_style) unless $no_recursion;
						
						if ($no_recursion) # set attributes for foreign classes if no recursion is enabled
						{
							$foreign_class_node->set_attribute('label', "$class_name");
							$foreign_class_node->set_attribute('font','Arial');
							if ($colorize)
							{
								$foreign_class_node->set_attribute('color','#666666');
								$foreign_class_node->set_attribute('fill','#dfefff');
								$foreign_class_node->set_attribute('bordercolor','#dddddd');
							}
						}
					}
				}
			}
			
			foreach my $rel (keys %{$class->meta_info->{'has_many'}})
			{	
				my $foreign_class = $class->meta_info->{'has_many'}->{$rel}->{foreign_class};
				if ($foreign_class->isa("Class::DBI")) #is the foreign class a Class::DBI class too?
				{
					my $foreign_class_name =  _prettify($foreign_class, $prettify);
					$graph = _graph_it($graph, [$foreign_class], $prettify, $colorize, $show_columns, $no_recursion, $arrow_style) unless $graph->node("$foreign_class") or $no_recursion; #unless $graph->node("$foreign_class") is to prevent deep recursion
				}
			}
			
			my ($class_node, $edge) = $graph->add_node("$class"); #add node for classes without any relationships.
			$class_node->set_attribute('label', "$class_name");
			$class_node->set_attribute('font','Arial');
			if ($colorize)
			{
				$class_node->set_attribute('color','#666666');
				$class_node->set_attribute('fill','#dfefff');
				$class_node->set_attribute('bordercolor','#dddddd');
			}
			if ($show_columns)
			{
				$graph = _show_columns($graph,$class,$class_name, $prettify, $colorize, $foreign_keys);
			}
			
		}
	}
	return $graph;
}

sub _prettify
{
	my $name = shift;
	my $prettify = shift;
	if ($prettify)
	{
		if ($name =~ /::/)
		{
			($name) = $name =~ /::([\w_]+)$/;
		}
		$name =~ s/_/ /g;
		$name =~ s/\b(\w)/\u$1/g;
	}
	return $name;	
}

sub _show_columns
{
	my $graph =shift;
	my $class = shift;
	my $class_name = shift;
	my $prettify = shift;
	my $colorize = shift;
	my $foreign_keys = shift;
	
	foreach my $column ($class->columns)
	{
		if ($column ne $class->primary_column and not exists $foreign_keys->{$column} and not $graph->node($class.'-'.$column))
		{ 
			my $column_name = _prettify($column, $prettify);
			my ($class_node, $column_node, $edge) = $graph->add_edge("$class", $class.'-'.$column);
			$column_node->set_attribute('label', "$column_name");
			$column_node->set_attribute('shape','circle');
			$column_node->set_attribute('font','Arial');
			$column_node->set_attribute('fontsize','0.9em');
			$edge->undirected(1);
			
			if ($colorize)
			{
				$column_node->set_attribute('color','grey');
				$column_node->set_attribute('bordercolor','#ff6600');
				$edge->set_attribute('color','grey');
			}
		}
	}
						
	return $graph;	
}

1;

__END__

=head1 METHODS

The public method is new().

=head2 new()

It returns an Graph::Easy object.

The following is a description of possible parameters.

=over

=item classes => \@your_cdbi_classes

This paramater is mandatory. It takes an arrayref of the Class::DBI classes that you would like to graph. The class list is NOT restricted by namespaces. 

=item prettify => 0 | 1

Defaulted to 0. If set to 1, the module will prettify your class and attribute (column) labels, for example, showing "Wonderful Class" instead of "some::wonderful_class". Please note that the actual names of the class nodes are NOT changed. To prevent naming collisions, attributes node names are concatenated with their class name using a hyphen, i.e. "Class::Name-Attribute_Name". Please refer to the Graph::Easy Manual for controlling per node or per edge attributes.

=item colorize => 0 | 1

Defaulted to 0. If set to 1, it will use a default color style.

=item show_columns => 0 | 1

Defaulted to 0. It controls whether to graph the attributes (columns) of the given Class::DBI classes. The module automatically hides primary key columns and foreign key columns founded in 'has a' relationships. Attribute (column) nodes are graphed as circles.

=item no_recursion => 0 | 1

Defaulted to 0.  If set to 1, the module will NOT traverses relationships automatically to discovery foreign classes.

=item flow => north | south | west | east

Defaulted to east. It is a shortcut to the flow directions of a graph suppported by Graph::Easy.

=item arrowstyle => open | closed | filled | none

Defaulted to open. It is a shortcut to the arrowstyles supported by Graph::Easy. It applies to all edges between classes. This option is handy since not all arrow styles are rendered nicely as html.

=back

=head2 _graph_it()

This is an internal API to construct the graph.

=head2 _prettify()

This is an internal API to prettify class labels and attribute (column) labels.

=head2 _show_columns()

This is an internal API for graphing attributes (columns).


=head1 SEE ALSO

L<Class::DBI>, L<Graph::Easy>.

=head1 AUTHOR

Xufeng (Danny) Liang danny@scm.uws.edu.au

=head1 COPYRIGHT & LICENSE

Copyright 2006 Xufeng (Danny) Liang, All Rights Reserved.

This program is free software; you can redistribute it and/or modify it
under the same terms as Perl itself.

=cut
