#!perl -T

# don't specify a plan so that we don't plan twice
use Test::More;

BEGIN {
	use_ok( 'Test::Dependencies', 'exclude',
                [qw/Some::Namespace Some::Other::Namespace/] );
}
