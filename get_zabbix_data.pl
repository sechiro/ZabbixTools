#!/usr/bin/perl
use strict;
use warnings;
use Socket;
use JSON;
my $json = JSON->new->allow_nonref;

my $zabbix_server = "localhost";
my $user = "Admin";
my $password = "zabbix";
my $useragent = "zabbi-tan";

# Auth
my $json_auth = $json->encode( create_auth_request_hash($user, $password) );
my $rpc_auth_request = create_rpc_request($zabbix_server, $useragent, $json_auth);
my $json_auth_result = $json->decode( get_zabbix_data($zabbix_server, $rpc_auth_request) );
my $auth = $json_auth_result->{result};
my $id = $json_auth_result->{id};
$id++;

# Get Zabbix Data
my $method = 'host.get'; 

my $json_data = $json->encode( create_get_request_hash($auth, $id, $method) );
my $rpc_request = create_rpc_request($zabbix_server, $useragent, $json_data);
my $json_result = $json->decode( get_zabbix_data($zabbix_server, $rpc_request) );

# test output
my $pretty_printed = $json->pretty->encode( $json_result );
print $pretty_printed;

# host test
my $host_array = $json_result->{result};
foreach my $host_result ( @$host_array ) { # $json_result->{result}[0]->{host}
    if ( $host_result->{host} eq "RecordingServer" ) {
        print "Host: $host_result->{host}\n";
        print "HostID: $host_result->{hostid}\n";
    }
}
exit;


sub create_auth_request_hash{
    my $user = shift;
    my $password = shift;
    
    my %params = (
        user    =>  $user,
        password    =>  $password,
    );
    my %auth_request = (
        auth        =>  undef,
        method      =>  'user.authenticate',
        id          =>  0,
        params       =>  \%params,
        jsonrpc     =>  '2.0',
    );
    return \%auth_request;
}

sub create_get_request_hash{ #for host.get etc.
    my $auth = shift;
    my $id = shift;
    my $method = shift;
    my $limit = shift;
    $limit = 100 unless defined($limit);
    
    my %params = (
        extendoutput    =>  'true',
        limit           =>  $limit,
    );
    my %get_request = (
        auth        =>  $auth,
        method      =>  $method,
        id          =>  $id,
        params       =>  \%params,
        jsonrpc     =>  '2.0',
    );
    return \%get_request;
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
    use Socket;
    my $zabbix_server = shift;
    my $rpc_request = shift;
    
    my $sock;
    socket( $sock, PF_INET, SOCK_STREAM, getprotobyname('tcp' ) )
        or die "Cannot create socket: $!";
    my $packed_remote_host = inet_aton( $zabbix_server )
    or die "Cannot pack $zabbix_server: $!";

    my $remote_port = 80; 

    # ホスト名とポート番号をパック
    my $sock_addr = sockaddr_in( $remote_port, $packed_remote_host )
        or die "Cannot pack $zabbix_server:$remote_port: $!";

    connect( $sock, $sock_addr )
        or die "Cannot connect $zabbix_server:$remote_port: $!";

    # 書き込みバッファリングをしない。
    my $old_handle = select $sock;
    $| = 1; 
    select $old_handle;

    print $sock "$rpc_request";
    
    shutdown $sock, 1; # 書き込みを終了する。

    
    # データの読み込み
    my $json_result;
    while( my $line = <$sock> ){
        if ( $line =~ /jsonrpc/ ){
            $json_result = $line;
        }
    }
    close $sock;
    return $json_result;
}

__END__