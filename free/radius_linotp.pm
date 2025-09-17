use strict;
use LWP 5.64;
use Config::File;
use Try::Tiny;
use vars qw(%RAD_REQUEST %RAD_REPLY %RAD_CHECK %RAD_CONFIG);

use constant RLM_MODULE_REJECT  => 0;
use constant RLM_MODULE_FAIL    => 1;
use constant RLM_MODULE_OK      => 2;
use constant RLM_MODULE_HANDLED => 3;
use constant RLM_MODULE_INVALID => 4;
use constant RLM_MODULE_USERLOCK => 5;
use constant RLM_MODULE_NOTFOUND => 6;
use constant RLM_MODULE_NOOP     => 7;
use constant RLM_MODULE_UPDATED  => 8;
use constant RLM_MODULE_NUMCODES => 9;

our $ret_hash = {
    0 => "RLM_MODULE_REJECT",
    1 => "RLM_MODULE_FAIL",
    2 => "RLM_MODULE_OK",
    3 => "RLM_MODULE_HANDLED",
    4 => "RLM_MODULE_INVALID",
    5 => "RLM_MODULE_USERLOCK",
    6 => "RLM_MODULE_NOTFOUND",
    7 => "RLM_MODULE_NOOP",
    8 => "RLM_MODULE_UPDATED",
    9 => "RLM_MODULE_NUMCODES"
};

use constant Debug => 1;
use constant Info  => 3;
use constant Error => 4;

our $CONFIG_FILE = "/etc/linotp2/rlm_perl.ini";
our $Config = {};
if ( -e $CONFIG_FILE ) {
    $Config = Config::File::read_config_file($CONFIG_FILE);
    $Config->{FSTAT} = "found!";
} else {
    $Config->{FSTAT} = "not found!";
    $Config->{URL}   = 'http://192.168.100.5:5000/validate/check';
    $Config->{REALM} = '';
    $Config->{RESCONF} = "";
    $Config->{Debug} = "TRUE";
    $Config->{SSL_CHECK} = "FALSE";
}

sub authenticate {
    &radiusd::radlog( Info, "=== LinOTP Authentication Started ===" );
    &radiusd::radlog( Info, "Config: $CONFIG_FILE ($Config->{FSTAT})" );

    my $URL     = $Config->{URL};
    my $REALM   = $Config->{REALM};
    my $RESCONF = $Config->{RESCONF};
    my $cafile  = $Config->{HTTPS_CA_FILE} || "";
    my $capath  = $Config->{HTTPS_CA_DIR}  || "";
    my $chkssl  = $Config->{SSL_CHECK} !~ /^\s*false\s*$/i;
    my $useNasIdentifier = $Config->{PREFER_NAS_IDENTIFIER} !~ /^\s*false\s*$/i;
    my $debug = $Config->{Debug} =~ /^\s*true\s*$/i;

    &radiusd::radlog( Info, "Auth URL: $URL" );
    &radiusd::radlog( Info, "User: $RAD_REQUEST{'User-Name'}" );

    my $auth_type = $RAD_CONFIG{"Auth-Type"};
    if ($auth_type) {
        if (exists($Config->{$auth_type}{URL})) {
            $URL = $Config->{$auth_type}{URL};
            &radiusd::radlog( Info, "Using type-specific URL: $URL" );
        }
        if (exists($Config->{$auth_type}{REALM})) {
            $REALM = $Config->{$auth_type}{REALM};
            &radiusd::radlog( Info, "Using type-specific REALM: $REALM" );
        }
        if (exists($Config->{$auth_type}{RESCONF})) {
            $RESCONF = $Config->{$auth_type}{RESCONF};
        }
    }

    my %params = ();
    if (exists($RAD_REQUEST{'State'})) {
        my $hexState = $RAD_REQUEST{'State'};
        $hexState = substr($hexState, 2) if substr($hexState, 0, 2) eq "0x";
        $params{'state'} = pack 'H*', $hexState;
        &radiusd::radlog( Info, "Challenge state detected" );
    }

    $params{"user"} = $RAD_REQUEST{'User-Name'} if exists $RAD_REQUEST{'User-Name'};
    $params{"pass"} = $RAD_REQUEST{'User-Password'} if exists $RAD_REQUEST{'User-Password'};

    if ($useNasIdentifier && exists($RAD_REQUEST{'NAS-IP-Address'})) {
        $params{"client"} = $RAD_REQUEST{'NAS-IP-Address'};
    } elsif ($useNasIdentifier && exists($RAD_REQUEST{'NAS-IPv6-Address'})) {
        $params{"client"} = $RAD_REQUEST{'NAS-IPv6-Address'};
    } elsif (exists($RAD_REQUEST{'Packet-Src-IP-Address'})) {
        $params{"client"} = $RAD_REQUEST{'Packet-Src-IP-Address'};
    } elsif (exists($RAD_REQUEST{'Packet-Src-IPv6-Address'})) {
        $params{"client"} = $RAD_REQUEST{'Packet-Src-IPv6-Address'};
    } else {
        &radiusd::radlog( Info, "Warning: No client IP found" );
    }

    $params{"realm"} = $REALM if length($REALM) > 0;
    $params{"resConf"} = $RESCONF if length($RESCONF) > 0;

    if ($debug) {
        for (keys %params) {
            &radiusd::radlog( Info, "Param: $_ = $params{$_}" );
        }
    }

    my $ua = LWP::UserAgent->new();
    if (!$chkssl) {
        $ua->ssl_opts(verify_hostname => 0, SSL_verify_mode => 0x00);
        &radiusd::radlog( Info, "SSL verification disabled" );
    } else {
        $ua->ssl_opts(verify_hostname => 1);
        $ua->ssl_opts(SSL_ca_file => $cafile) if length $cafile;
        $ua->ssl_opts(SSL_ca_path => $capath) if length $capath;
    }

    &radiusd::radlog( Info, "Sending request to LinOTP..." );
    my $response = $ua->post($URL, \%params);

    if (!$response->is_success) {
        &radiusd::radlog( Error, "HTTP Error: " . $response->status_line );
        $RAD_REPLY{'Reply-Message'} = "Server unreachable";
        return RLM_MODULE_FAIL;
    }

    my $content = $response->decoded_content();
    &radiusd::radlog( Info, "Raw Response: $content" );

    my $g_return = RLM_MODULE_REJECT;
    $RAD_REPLY{'Reply-Message'} = "Authentication failed";

    if ($content =~ /"value"\s*:\s*true/i) {
        &radiusd::radlog( Info, "SUCCESS: value=true found in response" );
        $RAD_REPLY{'Reply-Message'} = "Login successful";
        $g_return = RLM_MODULE_OK;
    }
    elsif ($content =~ /"value"\s*:\s*false/i) {
        &radiusd::radlog( Info, "REJECT: value=false in response" );
        $RAD_REPLY{'Reply-Message'} = "Invalid credentials";
        $g_return = RLM_MODULE_REJECT;
    }
    elsif ($content =~ /"status"\s*:\s*false/i) {
        &radiusd::radlog( Error, "ERROR: status=false in response" );
        $RAD_REPLY{'Reply-Message'} = "System error";
        $g_return = RLM_MODULE_FAIL;
    }
    elsif ($content =~ /:-\)/) {
        &radiusd::radlog( Info, "SUCCESS: Legacy OK response" );
        $RAD_REPLY{'Reply-Message'} = "Login successful";
        $g_return = RLM_MODULE_OK;
    }
    elsif ($content =~ /:-\(/) {
        &radiusd::radlog( Info, "CHALLENGE: Challenge response required" );
        if ($content =~ /:-\(\s+([^ ]+)\s+(.+)/) {
            $RAD_REPLY{'State'} = $1;
            $RAD_REPLY{'Reply-Message'} = $2;
            $RAD_CHECK{'Response-Packet-Type'} = "Access-Challenge";
        }
        $g_return = RLM_MODULE_HANDLED;
    }
    elsif ($content =~ /:-\//) {
        &radiusd::radlog( Info, "FAIL: Permanent failure" );
        $RAD_REPLY{'Reply-Message'} = "Authentication permanently failed";
        $g_return = RLM_MODULE_FAIL;
    }
    else {
        &radiusd::radlog( Info, "UNKNOWN: Unrecognized response" );
        $RAD_REPLY{'Reply-Message'} = "Server returned unknown response";
        $g_return = RLM_MODULE_REJECT;
    }

    &radiusd::radlog( Info, "Result: $ret_hash->{$g_return}" );
    return $g_return;
}

sub authorize { return RLM_MODULE_OK; }
sub preacct   { return RLM_MODULE_OK; }
sub accounting { return RLM_MODULE_OK; }
sub checksimul { return RLM_MODULE_OK; }
sub pre_proxy  { return RLM_MODULE_OK; }
sub post_proxy { return RLM_MODULE_OK; }
sub post_auth  { return RLM_MODULE_OK; }
sub detach { &radiusd::radlog( Info, "rlm_perl::Detaching" ); }

1;
