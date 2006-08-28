#/**
#
# Enhances HTTP::Daemon::ClientConn with the ability to directly invoke
# a object-specific event handler for the I/O handle whenever a
# HTTP::Daemon::Threaded::IOSelector object detects an event on the handle. Also
# provides interfaces to manage the handle's assignment to the
# read, write, and exception selectors within the HTTP::Daemon::Threaded::IOSelector
# object, as well as managing the removal from the selectors when
# the I/O handle is closed.
# <p>
# Copyright&copy 2006, Dean Arnold, Presicient Corp., USA<br>
# All rights reserved.
# <p>
# Licensed under the Academic Free License version 2.1, as specified in the
# License.txt file included in this software package, or at
# <a href='http://www.opensource.org/licenses/afl-2.1.php'>OpenSource.org</a>.
#
# @author D. Arnold
# @since 2005-12-01
# @self	$self
#
#*/
package HTTP::Daemon::Threaded::Socket;

use HTTP::Status;
use HTTP::Daemon;
use HTTP::Date qw(time2str);
use LWP::MediaTypes qw(guess_media_type);
use base qw(HTTP::Daemon::ClientConn);

use strict;
use warnings;

our $VERSION = '0.90';

our $CRLF = "\015\012";   # "\r\n" is not portable

#/**
# Handle an event on the socket. Invokes the handleSocketEvent()
# method on any registered context object.
#
# @param $eventmask	bitmask indicating read, write, or exception event
#
# @return		the context object
#*/
sub handleSocketEvent {
	my $self = shift;
	warn "Unimplemented handleSocketEvent() method!\n",
	return undef
		unless exists ${*$self}{_httpd_context};
	return ${*$self}{_httpd_context}->handleSocketEvent($self, @_);
}

#/**
# Close the socket. Removes the socket from the registered
# HTTP::Daemon::Threaded::IOSelector, closes the handle, and deletes any registered
# context and selector objects.
#
# @return		1
#*/
sub close {
	my $self = shift;
#
#	now support IO::Select removal
#
	${*$self}{_select_context}->removeAll($self)
		if exists ${*$self}{_select_context};
	$self->SUPER::close();
	delete ${*$self}{_httpd_context};
	delete ${*$self}{_select_context};
	return 1;
}
#
#	our method additions to manage
#	context objects
#
#/**
# Set the context object. The registered object should implement
# a handleSocketEvent() method. Also gets a printable peer IP address
#
# @param $context	the registered object
# @param $getpeer	boolean; true means get printable peer address
#
# @return		HTTP::Daemon::Threaded::Socket object
#*/
sub setContext {
	my ($self, $context, $getpeer) = @_;
	${*$self}{_httpd_context} = $context;
	if ($getpeer) {
		my ($port, $addr) = sockaddr_in(getpeername(*$self));
		${*$self}{_peer_addr} = inet_ntoa($addr);
	}
	return $self;
}

#/**
# Returns the current context object.
#
# @return		an object
#*/
sub getContext {
	my $self = shift;
	return ${*$self}{_httpd_context};
}

#/**
# Remove the context object.
#
# @return		HTTP::Daemon::Threaded::Socket object
#*/
sub removeContext {
	my $self = shift;
	delete ${*$self}{_httpd_context};
	delete ${*$self}{_peer_addr};
	return $self;
}
#
#	because of a catch-22 situation w/ IO::Select(),
#	we have to register the selectors here, so we
#	can remove ourselves on close()
#	NOTE: we assume the selector is a HTTP::Daemon::Threaded::IOSelector
#
#/**
# Set the HTTP::Daemon::Threaded::IOSelector object.
#
# @param $selector	the HTTP::Daemon::Threaded::IOSelector object
#
# @return		HTTP::Daemon::Threaded::Socket object
#*/
sub setSelector {
	my $self = shift;
	${*$self}{_select_context} = shift;
	return $self;
}

#/**
# Return the current selector.
#
# @return		HTTP::Daemon::Threaded::IOSelector object
#*/
sub getSelector {
	my $self = shift;
	return ${*$self}{_select_context};
}

#/**
# Remove selector object.
#
# @return		HTTP::Daemon::Threaded::Socket object
#*/
sub removeSelector {
	my $self = shift;
	delete ${*$self}{_select_context};
	return $self;
}
########################################
#
#	provide Selector i/fs thru ourselves
#	to simplify the code
#
########################################
#/**
# Add ourself to the selector's read selector
#
# @return		HTTP::Daemon::Threaded::IOSelector object
#*/
sub addRead {
	my $self = shift;
	return ${*$self}{_select_context}->addRead($self);
}

#/**
# Add ourself to the selector's write selector
#
# @return		HTTP::Daemon::Threaded::IOSelector object
#*/
sub addWrite {
	my $self = shift;
	return ${*$self}{_select_context}->addWrite($self);
}
#/**
# Add ourself to the selector's exception selector
#
# @return		HTTP::Daemon::Threaded::IOSelector object
#*/
sub addExcept {
	my $self = shift;
	return ${*$self}{_select_context}->addExcept($self);
}
#/**
# Add ourself to the selector's read and exception selectors
#
# @return		HTTP::Daemon::Threaded::IOSelector object
#*/
sub addNoWrite {
	my $self = shift;
	return ${*$self}{_select_context}->addNoWrite($self);
}
#/**
# Add ourself to all the selector's selectors
#
# @return		HTTP::Daemon::Threaded::IOSelector object
#*/
sub addAll {
	my $self = shift;
	return ${*$self}{_select_context}->addAll($self);
}

#/**
# Remove ourself from the selector's read selector
#
# @return		HTTP::Daemon::Threaded::IOSelector object
#*/
sub removeRead {
	my $self = shift;
	return ${*$self}{_select_context}->removeRead($self);
}

#/**
# Remove ourself from the selector's write selector
#
# @return		HTTP::Daemon::Threaded::IOSelector object
#*/
sub removeWrite {
	my $self = shift;
	return ${*$self}{_select_context}->removeWrite($self);
}
#/**
# Remove ourself from the selector's exception selector
#
# @return		HTTP::Daemon::Threaded::IOSelector object
#*/
sub removeExcept {
	my $self = shift;
	return ${*$self}{_select_context}->removeExcept($self);
}
#/**
# Remove ourself from the selector's read and exception selectors
#
# @return		HTTP::Daemon::Threaded::IOSelector object
#*/
sub removeNoWrite {
	my $self = shift;
	return ${*$self}{_select_context}->removeNoWrite($self);
}
#/**
# Remove ourself from all the selector's selectors
#
# @return		HTTP::Daemon::Threaded::IOSelector object
#*/
sub removeAll {
	my $self = shift;
	return ${*$self}{_select_context}->removeAll($self);
}
#/**
# Return response to a HEAD request for a file.
# Borrowed from HTTP::Daemon::ClientConn::send_file_response(),
# but with content omitted. Automatically write weblog entry
# if a WebLogger is configured.
#
# @params $file	path of file to be returned
#
# @return HTTP status of the response
#*/
sub send_file_header
{
	my ($self, $file) = @_;

	return $self->send_error(RC_NOT_IMPLEMENTED)
		if (-d $file);

	return $self->send_error(RC_NOT_FOUND)
		unless (-f _);

	my $f;
	sysopen($f, $file, 0) or
		return $self->send_error(RC_FORBIDDEN);

	binmode($f);
	my ($ct, $ce) = guess_media_type($file);
	my ($size, $mtime) = (stat _)[7,9];
	${*$self}{_httpd_context}->logRequest(${*$self}{_peer_addr}, RC_OK, $size);

	$self->send_basic_header;
	print $self "Content-Type: $ct$CRLF";
	print $self "Content-Encoding: $ce$CRLF"
		if $ce;
	print $self "Content-Length: $size$CRLF"
		if $size;
	print $self "Last-Modified: ", time2str($mtime), "$CRLF"
		if $mtime;
	print $self $CRLF;
    $self->flush();
	return RC_OK;
}

#/**
# Return response to a GET or POST request for a file.
# Overrides HTTP::Daemon::ClientConn::send_file_response().
# Automatically write weblog entry if a WebLogger is configured.
#
# @params $file	path of file to be returned
#
# @return HTTP status of the response
#*/
sub send_file_response
{
	my ($self, $file) = @_;

	return $self->send_error(RC_NOT_IMPLEMENTED)
		if (-d $file);

	return $self->send_error(RC_NOT_FOUND)
		unless (-f _);

	my $f;
	sysopen($f, $file, 0) or
		return $self->send_error(RC_FORBIDDEN);

	binmode($f);
	my ($ct, $ce) = guess_media_type($file);
	my ($size, $mtime) = (stat _)[7,9];
	${*$self}{_httpd_context}->logRequest(${*$self}{_peer_addr}, RC_OK, $size);

	$self->send_basic_header;
	print $self "Content-Type: $ct$CRLF";
	print $self "Content-Encoding: $ce$CRLF"
		if $ce;
	print $self "Content-Length: $size$CRLF"
		if $size;
	print $self "Last-Modified: ", time2str($mtime), "$CRLF"
		if $mtime;
	print $self $CRLF;
	$self->send_file($f);
    $self->flush();
	return RC_OK;
}
#/**
# Return parent WebClient object.
# Overrides HTTP::Daemon::ClientConn::daemon to return
#
# @return parent HTTP::Daemon::Threaded::WebClient object
#*/
sub daemon {
	my $self = shift;
	return ${*$self}{_httpd_context};
}
#/**
# Return response to a GET or POST request.
# Overrides HTTP::Daemon::ClientConn::send_response().
# Automatically writes weblog entry if a WebLogger is configured.
#
# @params $res	HTTP::Response object to generate response; alternately,
#		may be simple raw content, from which an HTTP::Response object
#		will be generated.
#
# @return HTTP status of the response
#*/
sub send_response
{
    my $self = shift;
    my $res = shift;

	$res ||= RC_OK,
	$res = HTTP::Response->new($res, @_)
	    unless (ref $res);

	${*$self}{_httpd_context}->logRequest(
		${*$self}{_peer_addr}, $res->code(), $res->content_length());
    $self->SUPER::send_response($res, @_);
    $self->flush();
    return $res->code();
}

#/**
# Return error response to a request.
# Overrides HTTP::Daemon::ClientConn::send_error().
# Automatically writes weblog entry if a WebLogger is configured.
#
# @param $status	<i>(optional)</i> HTTP status code of the error; default 400.
# @param $errormsg	<i>(optional)</i> Error message text to be included body of response.
#
# @return HTTP status of the response
#*/
sub send_error
{
    my $self = shift;
    my $status = shift;
    $status ||= RC_BAD_REQUEST;
	${*$self}{_httpd_context}->logRequest(${*$self}{_peer_addr}, $status);
    $self->SUPER::send_error($status, @_);
    $self->flush();
    return $status
}
#/**
# Return redirect response to a request.
# Overrides HTTP::Daemon::ClientConn::send_redirect().
# Automatically writes weblog entry if a WebLogger is configured.
#
# @param $loc		URL of new target location
# @param $status	<i>(optional)</i> redirect status code (default 301).
# @param $content	<i>(optional)</i> Any alternate content to be returned to client.
#
# @return HTTP status of the response
#*/
sub send_redirect
{
    my $self = shift;
    my ($loc, $status, $content) = @_;
    $status ||= RC_MOVED_PERMANENTLY;
	${*$self}{_httpd_context}->logRequest(${*$self}{_peer_addr}, $status);
    return $self->SUPER::send_redirect($loc, $status, $content);
}

#/**
# Get client request.
# Overrides HTTP::Daemon::ClientConn::get_request().
# Automatically extract weblog entry fragments if a WebLogger is configured.
#
# @param $only_headers		boolean; true => only retrieve HTTP headers
#
# @return HTTP::Request object
#*/
sub get_request
{
    my $self = shift;
    my $req = $self->SUPER::get_request(@_);
	${*$self}{_httpd_context}->scanForLogging($req)
		if $req;
	return $req;
}

1;