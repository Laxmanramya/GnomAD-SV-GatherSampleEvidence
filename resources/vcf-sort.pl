
#!/usr/bin/env perl
#
# Author: petr.danecek@sanger
#

use strict;
use warnings;
use Carp;

my $opts = parse_params();
sort_vcf($opts);

exit;

#--------------------------------

sub error
{
    my (@msg) = @_;
    if ( scalar @msg )
    {
        croak @msg;
    }
    die
        "Usage: vcf-sort > out.vcf\n",
        "       cat file.vcf | vcf-sort > out.vcf\n",
        "Options:\n",
        "   -c, --chromosomal-order       Use natural ordering (1,2,10,MT,X) rather then the default (1,10,2,MT,X). This requires\n",
        "                                     new version of the unix \"sort\" command which supports the --version-sort option.\n",
        "   -p, --parallel <int>          Change the number of sorts run concurrently to <int>\n",
        "   -t, --temporary-directory     Use a directory other than /tmp as the temporary directory for sorting.\n",
        "   -h, -?, --help                This help message.\n",
        "\n";
}

sub parse_params
{
    my $opts = {};
    while (my $arg=shift(@ARGV))
    {
        if ( $arg eq '-p' || $arg eq '--parallel-sort' ) { $$opts{parallel_sort}=shift(@ARGV); next; }
        if ( $arg eq '-c' || $arg eq '--chromosomal-order' ) { $$opts{chromosomal_order}=1; next; }
        if ( $arg eq '-?' || $arg eq '-h' || $arg eq '--help' ) { error(); }
        if ( $arg eq '-t' || $arg eq '--temporary-directory' ) { $$opts{temp_dir}=shift(@ARGV); next; }
        if ( -e $arg ) { $$opts{file}=$arg; next }
        error("Unknown parameter \"$arg\". Run -h for help.\n");
    }
    return $opts;
}

sub sort_vcf
{
    my ($opts) = @_;
    
    my $fh;
    if ( exists($$opts{file}) )
    {
        if ( $$opts{file}=~/\.gz$/i )
        {
            open($fh,"gunzip -c $$opts{file} |") or error("$$opts{file}: $!");
        }
        else
        {
            open($fh,'<',$$opts{file}) or error("$$opts{file}: $!");
        }
    }
    else { $fh = *STDIN; }

    my $sort_opts = check_sort_options($opts);
    my $cmd;
    
    if ( exists($$opts{temp_dir}) )
    {
		$cmd = "sort $sort_opts -T $$opts{temp_dir} -k2,2n";    
    }
    else
    {
    	$cmd = "sort $sort_opts -k2,2n";
    }
    print STDERR "$cmd\n";
    open(my $sort_fh,"| $cmd") or error("$cmd: $!");

    my $unflushed = select(STDOUT); 
    $| = 1; 
    while (my $line=<$fh>)
    {
        if ( $line=~/^#/ ) { print $line; next; }
        print $sort_fh $line;
        last;
    }
    select($unflushed);
    while (my $line=<$fh>)
    {
        print $sort_fh $line;
    }
}

sub check_sort_options
{
    my ($opts) = @_;

    my $sort_opts = join('',`sort --help`);
    my $has_version_sort = ( $sort_opts=~/\s+--version-sort\s+/ ) ? 1 : 0;
    my $has_parallel_sort = ( $sort_opts=~/\s+--parallel=/ ) ? 1 : 0;

    if ( $$opts{chromosomal_order} && !$has_version_sort ) 
    {
        error("Old version of sort command installed, please run without the -c option.\n");
    }
    if ( $$opts{parallel_sort} && !$has_version_sort ) 
    {
        error("Old version of sort command installed, please run without the -p option.\n");
    }
    $sort_opts  = ( $$opts{chromosomal_order} && $has_version_sort ) ? '-k1,1V' : '-k1,1d';
    if ( $$opts{parallel_sort} && $has_parallel_sort ) { $sort_opts .= " --parallel $$opts{parallel_sort}"; }
    
    return $sort_opts;
}

