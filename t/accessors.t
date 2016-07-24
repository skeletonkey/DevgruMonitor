#!/usr/bin/perl

use strict;
use warnings;

use Test::Exception;
use Test::Deep;
use Test::More; #tests => 24;
use Test::Output;
use Devgru::Monitor;

my $new_int = 400;

my %args = (
    node_data => {
        'arg1.arg2' => {
            template_vars => [qw(arg1 arg2)],
        },
        'arg3.arg4' => {
            template_vars => [qw(arg3 arg4)],
        },
        'arg5.arg6' => {
            template_vars => [qw(arg5 arg6)],
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

is($monitor->check_timeout, 5, 'Original check_timeout found');
throws_ok
    { $monitor->check_timeout('a') }
    qr/check_timeout needs to be an integer/, 'Bad check_timeout error';
$monitor->check_timeout($new_int);
is($monitor->check_timeout, $new_int, 'New check_timeout found');

is($monitor->down_confirm_count, 2, 'Original down_confirm_count found');
throws_ok
    { $monitor->down_confirm_count('a') }
    qr/down_confirm_count needs to be an integer/, 'Bad down_confirm_count error';
$monitor->down_confirm_count($new_int);
is($monitor->down_confirm_count, $new_int, 'New down_confirm_count found');

is($monitor->down_frequency, 60, 'Original down_frequency found');
throws_ok
    { $monitor->down_frequency('a') }
    qr/down_frequency needs to be an integer/, 'Bad down_frequency error';
$monitor->down_frequency($new_int);
is($monitor->down_frequency, $new_int, 'New down_frequency found');

is($monitor->up_frequency, 300, 'Original up_frequency found');
throws_ok
    { $monitor->up_frequency('a') }
    qr/up_frequency needs to be an integer/, 'Bad up_frequency error';
$monitor->up_frequency($new_int);
is($monitor->up_frequency, $new_int, 'New up_frequency found');

cmp_deeply($monitor->severity_thresholds, [25], 'Original severity_thresholds found');
throws_ok
    { $monitor->severity_thresholds(['a']); }
    qr/Severity Thresholds need to be integers/, 'Bad severity threshold found';
$monitor->severity_thresholds(25, 50);
cmp_deeply($monitor->severity_thresholds, [25,50], 'New severity_thresholds found from array');

throws_ok
    { $monitor->base_template('test'); }
    qr/base_template can only be provided with the new call/, 'base_template can not be updated';

throws_ok
    { $monitor->end_point_template('test'); }
    qr/end_point_template can only be provided with the new call/, 'base_template can not be updated';

is($monitor->last_version_check, 0, 'Original last_version_check found');
$monitor->last_version_check($new_int);
is($monitor->last_version_check, $new_int, 'New last_version_check found');

is($monitor->version_frequency, 86400, 'Original version_frequency found');
throws_ok
    { $monitor->version_frequency('a') }
    qr/version_frequency needs to be an integer/, 'Bad down_confirm_count error';
$monitor->version_frequency($new_int);
is($monitor->version_frequency, $new_int, 'New version_frequency found');

throws_ok { $monitor->get_node } qr/No node_name provided/, 'No node_name provided';
is($monitor->get_node('arg1.arg2')->name, 'arg1.arg2', 'node retrieved');

throws_ok { Devgru::Monitor->_check_node } qr/_check_node has not been implemented/, 'Check Node has not been implemented';

stderr_like { Devgru::Monitor->version_report } qr/version_report has not been implemented - return empty array/, 'Version Report has not been implemented';

cmp_deeply([Devgru::Monitor->version_report], [], 'Version Report returns an empty array');

cmp_bag([$monitor->get_node_names], ['arg1.arg2', 'arg3.arg4', 'arg5.arg6'], 'get_node_names works');

is($monitor->percent_nodes_down(), 0, 'All nodes are up');
$monitor->get_node('arg1.arg2')->status(Devgru::Monitor->SERVER_DOWN);
$monitor->get_node('arg1.arg2')->down_count($new_int + 10);
$monitor->get_node('arg3.arg4')->status(Devgru::Monitor->SERVER_DOWN);
$monitor->get_node('arg5.arg6')->status(Devgru::Monitor->SERVER_UP);
cmp_bag([$monitor->get_down_node_names], [ 'arg1.arg2' ], 'Found names of down nodes');
is($monitor->percent_nodes_down, 33, '1/3 nodes are down');

is($monitor->severity, 1, 'Severity of 1 was found');

done_testing();
