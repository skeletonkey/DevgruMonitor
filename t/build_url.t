#!/usr/bin/perl

use strict;
use warnings;

use Test::Exception;
use Test::More tests => 8;
use Devgru::Monitor;

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
);
my $monitor = Devgru::Monitor->new(
    %args,
    end_point_template => 'http://%s.%s.com/end_point',
);

my $node = $monitor->get_node('arg1.arg2');
is($monitor->build_template($node->template_vars),
    'http://arg1.arg2.com/end_point',
    'Correct Endpoint from template and vars');

$monitor = Devgru::Monitor->new(
    %args,
    end_point_template => '%s/end_point',
    base_template  => 'http://%s.%s.base.com',
);
is($monitor->build_template($node->template_vars),
    'http://arg1.arg2.base.com/end_point',
    'Correct Endpoint from base template and vars');
is($monitor->build_base_template($node->template_vars),
    'http://arg1.arg2.base.com',
    'Correct Base URL from base template and vars');
is($monitor->build_base_template(@{$node->template_vars}),
    'http://arg1.arg2.base.com',
    'Correct Base URL from base template and vars as a ref');

$monitor = Devgru::Monitor->new(%args);
throws_ok
    { $monitor->build_template() }
    qr/No url\/template args provied to build_template/, 'No args provided';
throws_ok
    { $monitor->build_base_template() }
    qr/No url\/template args provied to build_base_template/, 'No args provided';

throws_ok
    { $monitor->build_template(['arg1']) }
    qr/No end_point_template found/, 'No end_point_template found';
throws_ok
    { $monitor->build_base_template(['arg1']) }
    qr/No base_template found/, 'No base_template found';
