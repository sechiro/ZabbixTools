#!/usr/bin/perl
# Last Modified: 2010/12/19
# Author: Seiichiro, Ishida <twitterID: @sechiro>

use strict;
use warnings;
use IO::Socket::INET;
use JSON;
use Getopt::Long;

# JSON OO Interface
my $json = JSON->new->allow_nonref;

# Command Line Options
my $zabbix_server = "localhost";
my $user = "Admin"; # Zabbix default
my $password = "zabbix"; # Zabbix default
my $useragent = "zabbi-tan"; # できる子
my $method = "host.create";
my $hostname;
my $ip;
my $dnsname;
my $agentport = 10050;
my @hostgroups = ();
my @templates = ();
my $useip = 1;
my $limit; # 取得アイテム数の上限。サブルーチンの互換性向けに定義。

my $opt_parse = GetOptions (
    "zabbix_server=s" => \$zabbix_server,
    "user=s"        =>  \$user,
    "password=s"    =>  \$password,
    "useragent=s"   =>  \$useragent,
    "method=s"      =>  \$method,
    "agentport=i"   =>  \$agentport,
    "hostname=s"    =>  \$hostname,
    "ip=s"          =>  \$ip,
    "dnsname=s"     =>  \$dnsname,
    "hostgroups=s"  =>  \@hostgroups,
    "templates=s"   =>  \@templates,
    "useip=i"       =>  \$useip,
    "limit=i"       =>  \$limit,
);

die "Hostname is needed!" unless (defined($hostname));

# Authentication
my $json_auth = $json->encode( create_auth_request_hash($user, $password) );
my $rpc_auth_request = create_rpc_request($zabbix_server, $useragent, $json_auth);
my $json_auth_result = $json->decode( get_zabbix_data($zabbix_server, $rpc_auth_request) );
my $auth = $json_auth_result->{result};
my $id = $json_auth_result->{id};
$id++;

# Get hostgroups id
my @hostgroup_ids = ();
foreach my $hostgroup (@hostgroups) {
    my %hostgroup_filter = (
        name    =>  $hostgroup,
    );
    my $json_data = $json->encode( create_get_request_hash($auth, $id, "hostgroup.get", \%hostgroup_filter, $limit) );
    my $rpc_request = create_rpc_request($zabbix_server, $useragent, $json_data);
    my $json_result = $json->decode( get_zabbix_data($zabbix_server, $rpc_request) );
    my $result_array = $json_result->{result};
    foreach my $result ( @$result_array ) { # $json_result->{result}[n]->{groupid}
        push (@hostgroup_ids, $result->{groupid});
    }
    $id++;
}

# Get templates id
my @template_ids = ();
foreach my $template (@templates) {
    my %template_filter = (
        host    =>  $template,
    );
    my $json_data = $json->encode( create_get_request_hash($auth, $id, "template.get", \%template_filter, $limit) );
    my $rpc_request = create_rpc_request($zabbix_server, $useragent, $json_data);
    my $json_result = $json->decode( get_zabbix_data($zabbix_server, $rpc_request) );
    my $result_hash = $json_result->{result};
    foreach my $key ( keys %$result_hash ) { # keyの値はtemplateidと同じ。
        push (@template_ids, $result_hash->{$key}->{templateid});
    }
    $id++;
}

# Create Host
my $json_data = $json->encode( host_create_request_hash($auth, $id, $method, $hostname, $ip, $dnsname, $agentport, \@hostgroup_ids, \@template_ids, $useip) );
my $rpc_request = create_rpc_request($zabbix_server, $useragent, $json_data);
my $json_result = $json->decode( get_zabbix_data($zabbix_server, $rpc_request) );
$id++;

# output
my $pretty_printed = $json->pretty->encode( $json_result );
print $pretty_printed;

exit;


sub create_auth_request_hash{
    my $user = shift;
    my $password = shift;
    
    my %params = (
        user        =>  $user,
        password    =>  $password,
    );
    my %auth_request = (
        auth        =>  undef,
        method      =>  'user.authenticate',
        id          =>  0,
        params      =>  \%params,
        jsonrpc     =>  '2.0',
    );
    return \%auth_request;
}


sub create_get_request_hash{ #for host.get etc.
    my $auth = shift;
    my $id = shift;
    my $method = shift;
    my $filter_hash = shift;
    my $limit = shift;
    
    my %params = (
        output      =>  'extend',
        limit       =>  $limit,
        filter      =>  $filter_hash,
    );

    my %get_request = (
        auth        =>  $auth,
        method      =>  $method,
        id          =>  $id,
        params      =>  \%params,
        jsonrpc     =>  '2.0',
    );
    return \%get_request;
}


sub host_create_request_hash{ #for host.create
    my $auth = shift;
    my $id = shift;
    my $method = shift;
    my $hostname = shift;
    my $ip = shift;
    my $dnsname = shift;
    my $agentport = shift;
    my $hostgroup_ids = shift;
    my $template_ids = shift;
    my $useip = shift;
    
    my %params = (
        host        =>  $hostname,
        ip          =>  $ip,
        dns         =>  $dnsname,
        port        =>  $agentport,
        groups      =>  $hostgroup_ids, 
        templates   =>  $template_ids, 
        useip       =>  $useip,
    );

    my %request = (
        auth        =>  $auth,
        method      =>  $method,
        id          =>  $id,
        params      =>  \%params,
        jsonrpc     =>  '2.0',
    );
    return \%request;
}

sub create_rpc_request{
    my $zabbix_server = shift;
    my $useragent = shift;
    my $json_data = shift;
    my $header = "POST /zabbix/api_jsonrpc.php HTTP/1.1\n"
        . "Accept: */*\n"
        . "Connection: close\n"
        . "Content-Type: application/json-rpc\n";
    
    $header .= "User-Agent: " . $useragent ."\n";
    $header .= "Content-Length: " . length($json_data) . "\n";
    $header .= "Host: " . $zabbix_server . "\n\n";

    return $header . $json_data;
}

sub get_zabbix_data{
    use IO::Socket::INET;
    my $zabbix_server = shift;
    my $rpc_request = shift;
    
    my $sock = IO::Socket::INET->new(PeerAddr => "$zabbix_server",
                                     PeerPort => 'http(80)',
                                     Proto    => 'tcp',
        ) or die "Cannot create socket: $!";

    $sock->print("$rpc_request");
    
    # データの読み込み
    my $json_result;
    while( my $line = $sock->getline ){
        if ( $line =~ /jsonrpc/ ){
            $json_result = $line;
        }
    }
    return $json_result;
}


__END__