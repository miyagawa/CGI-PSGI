package CGI::PSGI;

use strict;
use 5.008_001;
our $VERSION = '0.01';

use base qw(CGI);

sub new {
    my($class, $env) = @_;
    CGI::initialize_globals();

    my $self = bless { psgi_env => $env }, $class;

    local *ENV = $env;
    $self->SUPER::init;

    $self;
}

sub read_from_client {
    my($self, $buff, $len, $offset) = @_;
    $self->{psgi_env}{'psgi.input'}->read($$buff, $len, $offset);
}

# copied from CGI.pm
sub read_from_stdin {
    my($self, $buff) = @_;

    my($eoffound) = 0;
    my($localbuf) = '';
    my($tempbuf) = '';
    my($bufsiz) = 1024;
    my($res);

    while ($eoffound == 0) {
        $res = $self->{psgi_env}{'psgi.input'}->read($tempbuf, $bufsiz, 0);

        if ( !defined($res) ) {
            # TODO: how to do error reporting ?
            $eoffound = 1;
            last;
        }
        if ( $res == 0 ) {
            $eoffound = 1;
            last;
        }
        $localbuf .= $tempbuf;
    }

    $$buff = $localbuf;

    return $res;
}

# copied and rearanged from CGI::header
sub psgi_header {
    my($self, @p) = @_;

    my(@header);

    my($type,$status,$cookie,$target,$expires,$nph,$charset,$attachment,$p3p,@other) =
        CGI::rearrange([['TYPE','CONTENT_TYPE','CONTENT-TYPE'],
                        'STATUS',['COOKIE','COOKIES'],'TARGET',
                        'EXPIRES','NPH','CHARSET',
                        'ATTACHMENT','P3P'],@p);

    $type ||= 'text/html' unless defined($type);
    if (defined $charset) {
        $self->charset($charset);
    } else {
        $charset = $self->charset if $type =~ /^text\//;
    }
    $charset ||= '';

    # rearrange() was designed for the HTML portion, so we
    # need to fix it up a little.
    my @other_headers;
    for (@other) {
        # Don't use \s because of perl bug 21951
        next unless my($header,$value) = /([^ \r\n\t=]+)=\"?(.+?)\"?$/;
        $header =~ s/^(\w)(.*)/"\u$1\L$2"/e;
        push @other_headers, $header, $self->unescapeHTML($value);
    }

    $type .= "; charset=$charset"
        if     $type ne ''
           and $type !~ /\bcharset\b/
           and defined $charset
           and $charset ne '';

    # Maybe future compatibility.  Maybe not.
    my $protocol = $self->{psgi_env}{SERVER_PROTOCOL} || 'HTTP/1.0';

    push(@header, "Status", $status) if $status;
    push(@header, "Window-Target", $target) if $target;
    if ($p3p) {
        $p3p = join ' ',@$p3p if ref($p3p) eq 'ARRAY';
        push(@header,"P3P", qq(policyref="/w3c/p3p.xml", CP="$p3p"));
    }

    # push all the cookies -- there may be several
    if ($cookie) {
        my(@cookie) = ref($cookie) && ref($cookie) eq 'ARRAY' ? @{$cookie} : $cookie;
        for (@cookie) {
            my $cs = UNIVERSAL::isa($_,'CGI::Cookie') ? $_->as_string : $_;
            push(@header,"Set-Cookie", $cs) if $cs ne '';
        }
    }
    # if the user indicates an expiration time, then we need
    # both an Expires and a Date header (so that the browser is
    # uses OUR clock)
    push(@header,"Expires", CGI::expires($expires,'http'))
        if $expires;
    push(@header,"Date", CGI::expires(0,'http')) if $expires || $cookie || $nph;
    push(@header,"Pragma", "no-cache") if $self->cache();
    push(@header,"Content-Disposition", "attachment; filename=\"$attachment\"") if $attachment;
    push(@header, @other_headers);

    push(@header,"Content-Type", $type) if $type ne '';

    $status ||= "200";
    $status =~ s/\D*$//;

    return $status, \@header;
}

# The list is auto generated and modified with:
# perl -nle '/^sub (\w+)/ and $sub=$1; \
#   /^}\s*$/ and do { print $sub if $code{$sub} =~ /[\%\$]ENV/; undef $sub };\
#   $code{$sub} .= "$_\n" if $sub; \
#   /^\s*package [^C]/ and exit' \
# `perldoc -l CGI`
for my $method (qw(
    url_param
    url
    cookie
    raw_cookie
    _name_and_path_from_env
    request_method
    content_type
    path_translated
    request_uri
    remote_host
    remote_addr
    server_name
    server_software
    server_port
    server_protocol
    http
    https
    remote_ident
    auth_type
    remote_user
    user_name
    read_multipart
    read_multipart_related
)) {
    no strict 'refs';
    *$method = sub {
        my $self  = shift;
        my $super = "SUPER::$method";
        local *ENV = $self->{psgi_env};
        $self->$super(@_);
    };
}

sub DESTROY {
    my $self = shift;
    CGI::initialize_globals();
}

1;
__END__

=encoding utf-8

=for stopwords

=head1 NAME

CGI::PSGI - Enable your CGI.pm aware applications to adapt PSGI protocol

=head1 SYNOPSIS

  use CGI::PSGI;

  sub app {
      my $env = shift;
      my $q = CGI::PSGI->new($env);
      return [ $q->psgi_header, [ $body ] ];
  }

=head1 DESCRIPTION

CGI::PSGI is an extension of CGI.pm to enable PSGI protocol in your
already CGI.pm aware applications. This module leaves CGI.pm core code
untouched, but makes your own code slightly modified.

Your application should call C<< CGI::PSGI->new($env) >> instead of
C<< CGI->new >> to create a new CGI object, in the same way how
L<CGI::Fast> object is being initialized in FastCGI environment.

C<psgi_header> method is added for your convenience if your
application uses C<< $cgi->header >> to generate header, but you are
free to ignore this method and instead can generate status code and
headers array ref by yourself.

If you want to run your CGI scripts unmodified under PSGI enviroments,
this module might not be for you: take a look at L<CGI::Emulate::PSGI>
instead.

=head1 AUTHOR

Tatsuhiko Miyagawa E<lt>miyagawa@bulknews.netE<gt>

=head1 LICENSE

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

=head1 SEE ALSO

L<CGI> L<CGI::Emulate::PSGI>

=cut
