package Class::DBI::GraphEasy;

use vars qw($VERSION @EXPORT);
use Exporter;
use vars qw(@ISA @EXPORT $VERSION $GRAPH_FILL $NODE_FONT $NODE_COLOR $NODE_FILL $NODE_BORDERCOLOR $EDGE_COLOR $COLUMN_NODE_FILL $COLUMN_NODE_FONTSIZE $COLUMN_BORDERCOLOR);
@ISA = qw(Exporter); 
@EXPORT = qw(new);

use strict;
use warnings;
use Graph::Easy;

our $VERSION = 0.07;

$GRAPH_FILL = 'white';
$NODE_FONT = 'Arial';
$NODE_COLOR = '#666666';
$NODE_FILL = '#dfefff';
$NODE_BORDERCOLOR = '#dddddd';
$EDGE_COLOR = 'grey';

$COLUMN_NODE_FILL = 'white';
$COLUMN_NODE_FONTSIZE = '0.9em';
$COLUMN_BORDERCOLOR = '#ff6600';

sub new
{
	my $self = shift;
	my %args = (@_);
    return unless ref $args{classes} eq 'ARRAY';
	my $graph = Graph::Easy->new();
	$graph->set_attribute('fill', $GRAPH_FILL); # otherwise firefox 2 will have a black background when rendered as svg
	$graph->set_attribute('flow', $args{flow}) if $args{flow};
	
	$graph->set_attribute('node', 'font', $NODE_FONT);
	$graph->set_attribute('node', 'shape', $args{class_shape}) if $args{class_shape};
	$graph->set_attribute('edge', 'arrowstyle', $args{arrow_style}) if $args{arrow_style};
	
	if ($args{colorize})
	{
		$graph->set_attribute('node', 'color', $NODE_COLOR);
		$graph->set_attribute('node', 'fill', $NODE_FILL);
		$graph->set_attribute('node', 'bordercolor', $NODE_BORDERCOLOR);
		$graph->set_attribute('edge', 'color', $EDGE_COLOR)
	}
	
	return _graph_it(graph => $graph, @_);
}

sub _graph_it
{
	my %args = (@_);
	my $graph = $args{graph};
	foreach my $class (@{$args{classes}})
	{
		
		if($class->isa("Class::DBI")) #check if it's a Class::DBI class 
		{
			my $class_name = _prettify(name => $class, prettify => $args{prettify});
			my $foreign_keys;
			foreach my $rel (keys %{$class->meta_info->{'has_a'}})
			{
				my $foreign_class = $class->meta_info->{'has_a'}->{$rel}->{foreign_class};
				$foreign_keys->{$class->meta_info->{'has_a'}->{$rel}->{accessor}->{name}} = undef;
				my $foreign_class_name =  _prettify(name => $foreign_class, prettify => $args{prettify});
				if ($foreign_class->isa("Class::DBI") and not $graph->edge("$class", "$foreign_class")) #is the foreign class a Class::DBI class too?
				{
					my ($class_node, $foreign_class_node, $edge) = $graph->add_edge("$class", "$foreign_class");
					
					if ($args{no_recursion}) # set attributes for foreign classes if no recursion is enabled
					{
						$foreign_class_node->set_attribute('label', $foreign_class_name);
					}
					else
					{
						my %new_args = %args;
						$new_args{classes} = [$foreign_class];
						$new_args{graph} = $graph;
						$graph = _graph_it(%new_args);
					}
				}
			}
			
			unless ($args{no_recursion})
			{			
				foreach my $rel (keys %{$class->meta_info->{'has_many'}})
				{	
					my $foreign_class = $class->meta_info->{'has_many'}->{$rel}->{foreign_class};
					if ($foreign_class->isa("Class::DBI") and not $graph->node("$foreign_class")) #is the foreign class a Class::DBI class too?
					{
						my $foreign_class_name =  _prettify(name => $foreign_class, prettify => $args{prettify});
						my %new_args = %args;
						$new_args{classes} = [$foreign_class];
						$new_args{graph} = $graph;
						$graph = _graph_it(%new_args);			
					}
				}
			}
			
			my $class_node = $graph->add_node("$class"); #add node for classes without any relationships.
			$class_node->set_attribute('label', $class_name);
			
			if ($args{show_columns})
			{
				my %new_args = %args;
				$new_args{foreign_keys} = $foreign_keys;
				$new_args{graph} = $graph;
				$new_args{class} =  $class;
				$new_args{class_name} = $class_name;
				$new_args{column_shape} = $args{column_shape} if $args{column_shape};
				$graph = _show_columns(%new_args);
			}
			
		}
	}
	return $graph;
}

sub _prettify
{
	my %args = (@_);
	my $name = $args{name};
	if ($args{prettify})
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
	my %args = (@_);
	my $graph = $args{graph};
	foreach my $column ($args{class}->columns)
	{
		unless (map {$_ =~ /^$column$/} $args{class}->primary_columns or exists $args{foreign_keys}->{$column} or $graph->node($args{class}.'-'.$column))
		{ 
			my $column_name = _prettify(name => $column, prettify => $args{prettify});
			my ($class_node, $column_node, $edge) = $graph->add_edge($args{class}, $args{class}.'-'.$column);
			$column_node->set_attribute('label', "$column_name");
			$column_node->set_attribute('fontsize', $COLUMN_NODE_FONTSIZE);
			$edge->undirected(1);
			
			if ($args{colorize})
			{
				$column_node->set_attribute('fill', $COLUMN_NODE_FILL);
				$column_node->set_attribute('bordercolor', $COLUMN_BORDERCOLOR);
			}
			
			defined $args{column_shape} ? $column_node->set_attribute('shape', $args{column_shape}):$column_node->set_attribute('shape','circle');
		}
	}
						
	return $graph;	
}

1;

__END__


=head1 NAME

Class::DBI::GraphEasy - Graph Class::DBI classes automatically.

=head1 SYNOPSIS

    my $graph = Class::DBI::GraphEasy->new(
					classes => ['Music::Artist','Music::CD'], 
					prettify => 1, 
					colorize => 1, 
					show_columns => 1, 
					no_recursion => 0,
    				); #returns a Graph::Easy object
	
	print $graph->as_html_file(); #render $graph as html for rapid graphing
	my $graphviz = $graph->as_graphviz(); #render as graphviz for best results

=head1 DESCRIPTION

This module integrates Class::DBI and Graph::Easy. It is designed to automatically generate diagrams to illustrate the given Class::DBI classes. By default, it traverses both 'has a' and 'has many' relationships to discovery foreign classes recursively until not further relationships are found.

=head1 METHODS

The public method is new().

=head2 new()

It returns an Graph::Easy object or false when failed.

The following is a description of possible parameters.

=over

=item classes => \@your_cdbi_classes

This paramater is mandatory. It takes an arrayref of the Class::DBI classes (package names) that you would like to graph. The list is NOT restricted by namespaces. 

=item prettify => 0 | 1

Defaulted to 0. If set to 1, the module will prettify your class and attribute (column) labels, for example, showing "Wonderful Class" instead of "some::wonderful_class". Please note that the actual names of the class nodes are NOT changed. To prevent naming collisions, attributes node names are concatenated with their class name using a hyphen, i.e. "Class::Name-Attribute_Name". Please refer to the Graph::Easy Manual for controlling per node or per edge attributes.

=item colorize => 0 | 1

Defaulted to 0. If set to 1, it will use a default color schema. The easiest way to change this is by modifying the values of the exported variables (requires 0.05+).

=item show_columns => 0 | 1

Defaulted to 0. It controls whether to graph the attributes (columns) of the given Class::DBI classes. The module automatically hides primary key columns and foreign key columns founded in 'has a' relationships. 

=item no_recursion => 0 | 1

Defaulted to 0.  If set to 1, the module will NOT traverse relationships automatically to discovery foreign classes.

=item flow => north | south | west | east ...

Defaulted to east. It is a shortcut to the flow directions of a graph suppported by Graph::Easy.

=item arrowstyle => open | closed | filled | none

Defaulted to open. It is a shortcut to control the arrowstyles supported by Graph::Easy. It applies to all edges between classes. This option is handy since not all arrow styles are rendered nicely as html.

=item class_shape => circle | diamond | ellipse ...

Defaulted to rect (rectangle).  It is a shortcut to control the shape of all classes. Please refer to the Graph::Easy Manual for all possible shapes.  

=item column_shape => circle | diamond | ellipse ...

Defaulted to circle. It is a shortcut to control the shape of all attributes (columns). Please refer to the Graph::Easy Manual for all possible shapes. 

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
