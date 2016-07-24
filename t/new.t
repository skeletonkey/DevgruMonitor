#!/usr/bin/perl

use 5.006;
use strict;
use warnings;

use Test::More tests => 22;
use Test::Deep;
use Test::Exception;
use Test::Output;

#plan tests => 4;

use_ok( 'Devgru::Monitor' );

my $monitor;

throws_ok { $monitor = Devgru::Monitor->new() }
    qr/^No type provided/,
    'No type provided';
throws_ok { $monitor = Devgru::Monitor->new(type => 'Foo') }
    qr/^Unable to find correct monitoring class \(Devgru::Monitor::Foo\)/,
    'Bad Type';
throws_ok { $monitor = Devgru::Monitor->new(type => 'TSCMS') }
    qr/^No node_data provided/,
    'Missing node_data';

my %args = (
    type      => 'TSCMS',
    node_data => {
        'app1.phx1' => {
            end_point => 'this is my end_point',
        },
        'app2.phx1' => {
            template_vars => ['app2', 'phx1'],
        },
    },
    end_point_template => 'http://%s.shared.%s.websys.tmcs',
);

stderr_like { $monitor = Devgru::Monitor->new(%args); }
    qr/No up_frequency provided/,
    'No up_frequency warning found';
is($monitor->up_frequency, 300, 'Default up_frequency found');

$args{up_frequency} = 400;
stderr_like { $monitor = Devgru::Monitor->new(%args); }
    qr/No down_frequency provided/,
    'No down_frequency warning found';
is($monitor->down_frequency, 60, 'Default down_frequency found');

$args{down_frequency} = 400;
stderr_like { $monitor = Devgru::Monitor->new(%args); }
    qr/No version_frequency provided/,
    'No version_frequency warning found';
is($monitor->version_frequency, 0, 'Default version_frequency found');

$args{version_frequency} = 400;
stderr_like { $monitor = Devgru::Monitor->new(%args); }
    qr/No severity thresholds provided/,
    'No severity_thresholds warning found';
cmp_deeply($monitor->severity_thresholds, [], 'Default severity_thresholds found');

$args{severity_thresholds} = [1, 2];
stderr_like { $monitor = Devgru::Monitor->new(%args); }
    qr/No check_timeout provided/,
    'No check_timeout warning found';
is($monitor->check_timeout, 5, 'Default check_timeout found');

$args{check_timeout} = 400;
stderr_like { $monitor = Devgru::Monitor->new(%args); }
    qr/No down_confirm_count provided/,
    'No down_confirm_count warning found';
is($monitor->down_confirm_count, 0, 'Default down_confirm_count found');

$args{down_confirm_count} = 400;
$monitor = Devgru::Monitor->new(%args);

is($monitor->up_frequency, 400, 'Custom up_frequency found');
is($monitor->down_frequency, 400, 'Custom down_frequency found');
is($monitor->version_frequency, 400, 'Custom version_frequency found');
cmp_deeply($monitor->severity_thresholds, [1, 2], 'Custom severity_thresholds found');
is($monitor->check_timeout, 400, 'Custom check_timeout found');
is($monitor->down_confirm_count, 400, 'Custom down_confirm_count found');
