#!/usr/bin/perl
# Last Modified: 2010/02/27
# Author: Seiichiro, Ishida <twitterID: @sechiro>
# Script Name: get_niconico_cert.pl
use strict;
use warnings;
use IO::Socket::INET;
use JSON;
use Getopt::Long;

# JSON OO Interface
my $json = JSON->new->allow_nonref;

# Command Line Options
my $zabbix_server = "192.168.11.201";
my $user = "Admin"; # Zabbix default
my $password = "zabbix"; # Zabbix default
my $useragent = "zabbi-tan";
my $method = "item.get";
my $limit = 10; # 一度に取得するアイテム数
my $filter; # ex)   --method host.get --filter '{"host":"secure.niconico.jp"}'
            #       --method item.get --filter '{"hostid":["10001","10017"],"description":"Buffers memory"}'
my $opt_parse = GetOptions (
    "zabbix_server=s" => \$zabbix_server,
    "user=s"        =>  \$user,
    "password=s"    =>  \$password,
    "useragent=s"   =>  \$useragent,
    "method=s"      =>  \$method,
    "limit=i"       =>  \$limit,
    "filter=s"      =>  \$filter,
);


die "No method specified!" unless ( defined($method) );
my $filter_hash = $json->decode( $filter ) if ( defined($filter) );

# Authentication
my $json_auth = $json->encode( create_auth_request_hash($user, $password) );
my $rpc_auth_request = create_rpc_request($zabbix_server, $useragent, $json_auth);
my $json_auth_result = $json->decode( get_zabbix_data($zabbix_server, $rpc_auth_request) );
my $auth = $json_auth_result->{result};
my $id = $json_auth_result->{id};
$id++;

# Get Zabbix Data
my $json_data = $json->encode( create_get_request_hash($auth, $id, $method, $filter_hash, $limit) );
my $rpc_request = create_rpc_request($zabbix_server, $useragent, $json_data);
my $json_result = $json->decode( get_zabbix_data($zabbix_server, $rpc_request) );
my $last_value = $json_result->{result}[0]->{lastvalue};
print $last_value;
# output
my $sstp_server = "localhost";
my $agent = "zabbi-tan";
my $pretty_printed = $json->pretty->encode( $json_result);
#print $pretty_printed;

my $message = 'secure.nicovideo.jpの証明書が失効するまで、\nあと' . $last_value . '日のようね。\n';
if ( $last_value <= 30 ) {
    $message .= 'そろそろ運営に教えてあげた方がいいかしら。';
}

$message .= '\e';

my $sstp_script = '\0\s[' . 0 . ']' . $message;
my $sstp_request = create_sstp_request($sstp_script, $agent);

send_sstp($sstp_server, $sstp_request);


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
    my @itemids = ("25658");
    
    my %params = (
        output      =>  'extend',
        limit       =>  $limit,
        itemids       =>  \@itemids,
        filter      =>  $filter,
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


sub create_sstp_request {
    my $message = shift;
    my $agent = shift;
    my $request = 'SEND SSTP/1.4' ."\r\n"
        .'Sender: ' . "$agent" . "\r\n"
        .'Script: ' . "$message" . '\e' ."\r\n"
        .'Charset: UTF8' ."\r\n"
        ."\r\n";
    return $request;
}

sub timeout_message {
    print "Request TIMEOUT\n\n";
}

sub send_sstp{
    use IO::Socket::INET;
    my $sstp_server = shift;
    my $sstp_request = shift;
    
    my $sock = IO::Socket::INET->new(PeerAddr => "$sstp_server",
                                     PeerPort => '9801',
                                     Proto    => 'tcp',
        ) or die "Cannot create socket: $!";

    alarm(2);
    $SIG{'ALRM'} = timeout_message();
    $sock->print("$sstp_request");
    alarm(0);
    
    # データの読み込み
    while( my $line = $sock->getline ){
        print $line;
    }
}



__END__