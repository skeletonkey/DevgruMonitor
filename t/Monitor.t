#!/usr/bin/perl

use 5.006;
use strict;
use warnings;

use Test::More;
use Test::Exception;

plan tests => 1;

BEGIN {
    use_ok( 'Devgru::Monitor' );
    use_ok('Devgru::Monitor::Node') || die('Devgru::Monitor::Node not installed');
}


my $obj;

ok(1);
ok(1);

throws_ok { $obj = Devgru::Monitor->new() } qr/^No type provided/, 'No type provided';
throws_ok { $obj = Devgru::Monitor->new(type => 'Foo') } qr/^Unable to find correct monitoring class \(Devgru::Monitor::Foo\)/, 'Bad Type';
throws_ok { $obj = Devgru::Monitor->new(type => 'TSCMS') } qr/^No node_data provided/, 'Missing node_data';
