package Devgru::Monitor;

use 5.006;
use strict;
use warnings;

use Carp;
use Devgru::Node;

use constant SERVER_DOWN     => 0;
use constant SERVER_UNSTABLE => -1;
use constant SERVER_UP       => 1;

=head1 NAME

Devgru::Monitor - Interface to Monitoring modules

=head1 VERSION

Version 0.01

=cut

our $VERSION = '0.01';

=head1 SYNOPSIS

Creates the interface for all monitoring modules.

It creats two endpoints for use:
is_node_up         - detemine the state of a node
percent_nodes_down - returns an integer representing the presentage of nodes down
version_report     - return versions of each node

=head1 SUBROUTINES/METHODS

=head2 new

Create a new instance of the monitor.  When creating the instance a list of nodes
needs to be provided.

  my $monitor = Devgru::Monitor->new(
    node_data => {
        node_name => {
            end_point => 'http://url.to/end/point/that/is/used/to/monitor/node',
        },
    },
    type => 'node_type',
    up_frequency => 300, # seconds between checking a node that was last seen as upon
    down_frequency => 60, # seconds between checking a node that was last seen as down
    down_confirm_count => 2, # how many down report before we actually consider it down
    version_frequency => 86400, # seconds between version checks - 0 means don't check
    severity_thresholds => [ 25 ], # percentages of down threshold - used by severity method
    check_timeout => 5, # connection timeout in seconds for deteriming the state of a node
  );

=cut

sub new {
    my $package = shift;
    my $class = ref($package) || $package;

    my $self = {@_};
    if ($self->{type}) {
        $class .= '::' . delete $self->{type};
        eval "require $class";
        croak("Unable to find correct monitoring class ($class): $@") if $@;
    }
    else {
        croak("No type provided");
    }
    if ($self->{node_data}) {
        my $node_data = delete $self->{node_data};
        foreach my $node_name (keys %$node_data) {
            $self->{_nodes}{$node_name} = Devgru::Node->new(%{$node_data->{$node_name}}, name => $node_name);
        }
    }
    else {
        croak("No node_data provided");
    }
    if (! exists $self->{up_frequency}) {
        carp("No up_frequency provided! Using default value: 300 seconds");
        $self->{up_frequency} = 300;
    }
    if (! exists $self->{down_frequency}) {
        carp("No down_frequency provided! Using default value: 60 seconds");
        $self->{down_frequency} = 60;
    }
    if (! exists $self->{version_frequency}) {
        carp("No version_frequency provided! Using default value: 0 seconds - it will not check for versions");
        $self->{version_frequency} = 0;
    }
    if (! exists $self->{severity_thresholds}) {
        carp("No severity thresholds provided! Using default value of an empty array");
        $self->{severity_thresholds} = [];
    }
    if (! exists $self->{check_timeout}) {
        carp("No check_timeout provided! Using default value: 5 seconds");
        $self->{check_timeout} = 5;
    }
    if (! exists $self->{down_confirm_count}) {
        carp("No down_confirm_count provided! Using default value: 0");
        $self->{down_confirm_count} = 0;
    }

    $self->{last_version_check} = 0;

    return bless($self, $class);
}

sub get_check_timeout       { return shift->{check_timeout};       }
sub get_down_confirm_count  { return shift->{down_confirm_count};  }
sub get_down_frequency      { return shift->{down_frequency};      }
sub get_severity_thresholds { return shift->{severity_thresholds}; }
sub get_url_template        { return shift->{url_template};        }
sub get_up_frequency        { return shift->{up_frequency};        }
sub get_version_frequency   { return shift->{version_frequency};   }

sub last_version_check {
    my $self = shift;

    if (defined $_[0]) {
        $self->{last_version_check} = $_[0];
    }

    return $self->{last_version_check};
}

=head get_node

Provied a node name and get back a Devgru::Node object

=cut
sub get_node {
    my $self = shift;
    my $node_name = shift || croak("No node_name provided to get_node_data");

    return $self->{_nodes}{$node_name};
}

=head2 is_node_up

Used to determine the state of the node.

It returns the following:
1  - server is up and good
-1 - server is up but degraded
0  - server is NOT up

=over 2

=item node_name

The name of the node that was registered with the object upon creation to check.

=back

=cut

sub is_node_up {
    my $self = shift;
    my $node_name = shift || croak("No node name provided to is_node_up");

    my $node = $self->get_node($node_name);

    my $last_check = $node->last_check;
    if (
        !$last_check
        || ($node->status == $self->SERVER_UP && (time - $last_check > $self->get_up_frequency))
        || (time - $last_check > $self->get_down_frequency)
       ) {
        $node->last_check(time);
        $self->_check_node($node_name);
    }

    return $node->status;
}

=head2 _check_node

This method needs to be implemented by each monitoring module to return the
proper state (see is_node_up).

=cut
sub _check_node {
    croak("_check_node has not been implemented");
}

=head2 version_report

Returns an array of array refs with the following format:
    (
        [ version, node1, node2, ...],
        [ version, node3, node4, ...], 
    )

If a version report can not be generated (due to the information not being available)
then a one element array with an empty hash ref is returned.

=cut
sub version_report {
    carp("version_report has not been implemented - return empty array");
    return ();
}

=head2 percent_nodes_down

Returns an integer representing the number of nodes that are down based on the
return of get_down_node_names

=cut
sub percent_nodes_down {
    my $self = shift;

    return scalar($self->get_down_node_names) / scalar($self->get_node_names) * 100;
}

=head get_down_node_names

Even though the name says down it actually returns a count of all nodes that are
not in a UP state.  So this includes down and unhealthy nodes.

Nodes are considered 'down' if their status is NOT UP and they have failed at
least 'down_confirm_count' conecutive times.

=cut

sub get_down_node_names {
    my $self = shift;

    my @names = ();
    foreach my $node_name ($self->get_node_names) {
        my $node = $self->get_node($node_name);
        push(@names, $node_name)
            if $node->status ne SERVER_UP
                && $node->down_count >= $self->get_down_confirm_count;
    }

    return @names;;
}

=head2 get_node_names

Return a list of node names that were registered with the object upon creation.

=cut

sub get_node_names {
    my $self = shift;
    return keys %{$self->{_nodes}};
}

=head2 severity

Uses severity_thresholds to return a severity number.  It increments by one for
each threshold passed.

So if nothing is wrong severity is 0.

You decide how many thresholds you want.

Example: severity_thresholds => [ 10, 20, 40, 80 ];

If 15% of servers are down then the severity will be 1; if 50% then it's 3.

See get_down_node_names for an explination when nodes are considered DOWN.

=cut
sub severity {
    my $self = shift;

    my $severity = 0;

    my $down_percent = $self->percent_nodes_down;

    foreach my $threshold (sort { $a <=> $b } @{$self->get_severity_thresholds}) {

        if ($threshold <= $down_percent) {
            $severity++;
        }
        elsif ($threshold > $down_percent) {
            last;
        }
    }

    return $severity;
}

=head2 build_url

Use this to combine the url_template with it's template_vars.

=cut
sub build_url {
    my $self = shift;
    my $node_name = shift || croak('No node_name provided to build_url');

    croak('No url_template found') unless $self->get_url_template;

    my $node = $self->get_node($node_name);

    croak('No node found') unless $node;
    croak('No template_vars found for node ' . $node_name) unless $node->template_vars;

    return sprintf($self->get_url_template, @{$node->template_vars});
}



=head1 AUTHOR

Erik Tank, C<< <tank at jundy.com> >>

=head1 BUGS

Please report any bugs or feature requests to C<bug-devgru-monitor at rt.cpan.org>, or through
the web interface at L<http://rt.cpan.org/NoAuth/ReportBug.html?Queue=Devgru-Monitor>.  I will be notified, and then you'll
automatically be notified of progress on your bug as I make changes.

=head1 SUPPORT

You can find documentation for this module with the perldoc command.

    perldoc Devgru::Monitor


You can also look for information at:

=over 4

=item * RT: CPAN's request tracker (report bugs here)

L<http://rt.cpan.org/NoAuth/Bugs.html?Dist=Devgru-Monitor>

=item * AnnoCPAN: Annotated CPAN documentation

L<http://annocpan.org/dist/Devgru-Monitor>

=item * CPAN Ratings

L<http://cpanratings.perl.org/d/Devgru-Monitor>

=item * Search CPAN

L<http://search.cpan.org/dist/Devgru-Monitor/>

=back


=head1 ACKNOWLEDGEMENTS


=head1 LICENSE AND COPYRIGHT

Copyright 2016 Erik Tank.

This program is free software; you can redistribute it and/or modify it
under the terms of the the Artistic License (2.0). You may obtain a
copy of the full license at:

L<http://www.perlfoundation.org/artistic_license_2_0>

Any use, modification, and distribution of the Standard or Modified
Versions is governed by this Artistic License. By using, modifying or
distributing the Package, you accept this license. Do not use, modify,
or distribute the Package, if you do not accept this license.

If your Modified Version has been derived from a Modified Version made
by someone other than you, you are nevertheless required to ensure that
your Modified Version complies with the requirements of this license.

This license does not grant you the right to use any trademark, service
mark, tradename, or logo of the Copyright Holder.

This license includes the non-exclusive, worldwide, free-of-charge
patent license to make, have made, use, offer to sell, sell, import and
otherwise transfer the Package with respect to any patent claims
licensable by the Copyright Holder that are necessarily infringed by the
Package. If you institute patent litigation (including a cross-claim or
counterclaim) against any party alleging that the Package constitutes
direct or contributory patent infringement, then this Artistic License
to you shall terminate on the date that such litigation is filed.

Disclaimer of Warranty: THE PACKAGE IS PROVIDED BY THE COPYRIGHT HOLDER
AND CONTRIBUTORS "AS IS' AND WITHOUT ANY EXPRESS OR IMPLIED WARRANTIES.
THE IMPLIED WARRANTIES OF MERCHANTABILITY, FITNESS FOR A PARTICULAR
PURPOSE, OR NON-INFRINGEMENT ARE DISCLAIMED TO THE EXTENT PERMITTED BY
YOUR LOCAL LAW. UNLESS REQUIRED BY LAW, NO COPYRIGHT HOLDER OR
CONTRIBUTOR WILL BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, OR
CONSEQUENTIAL DAMAGES ARISING IN ANY WAY OUT OF THE USE OF THE PACKAGE,
EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.


=cut

1; # End of Devgru::Monitor
