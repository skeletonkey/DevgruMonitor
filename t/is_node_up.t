#!/usr/bin/perl

use strict;
use warnings;

use Test::Exception;
use Test::More tests => 6;
use Test::Mock::Simple;

use Devgru::Monitor;

my $monitor_mock = Test::Mock::Simple->new(module => 'Devgru::Monitor::TSCMS');
$monitor_mock->add(_check_node => sub { 
    my $self = shift;
    my $node = $self->get_node('arg1.arg2');
    $node->status(Devgru::Monitor->SERVER_UP);
});

my %args = (
    node_data => {
        'arg1.arg2' => {
            template_vars => [qw(arg1 arg2)],
        },
    },
    type => 'TSCMS',
    up_frequency => 300,
    down_frequency => 60,
    down_confirm_count => 2,
    version_frequency => 86400,
    severity_thresholds => [ 25 ],
    check_timeout => 5,
    end_point_template => 'http://%s.%s.com/end_point',
);
my $monitor = Devgru::Monitor->new(%args);

throws_ok { $monitor->is_node_up } qr/No node name provided to is_node_up/, 'No node name provided';

my ($status, $fresh) = $monitor->is_node_up('arg1.arg2');
is($status, Devgru::Monitor->SERVER_UP, 'Server is up');
is($fresh, 1, 'It is a fresh reading');

($status, $fresh) = $monitor->is_node_up('arg1.arg2');
is($status, Devgru::Monitor->SERVER_UP, 'Server is still up');
is($fresh, 0, 'It is NOT a fresh reading');

$status = $monitor->is_node_up('arg1.arg2');
is($status, Devgru::Monitor->SERVER_UP, 'Server is still up in scalar context');
