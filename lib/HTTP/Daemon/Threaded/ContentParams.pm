#/**
# Abstract base container class for
# application specific Content handler parameters.
# <p>
# Copyright&copy 2006, Dean Arnold, Presicient Corp., USA<br>
# All rights reserved.
# <p>
# Licensed under the Academic Free License version 2.1, as specified in the
# License.txt file included in this software package, or at
# <a href='http://www.opensource.org/licenses/afl-2.1.php'>OpenSource.org</a>.
#
# @author D. Arnold
# @since 2006-08-21
# @self	$self
#
#*/
package HTTP::Daemon::Threaded::ContentParams;

use strict;
use warnings;

our $VERSION = '0.90';
#/**
# Constructor. Populates itself with any handler
# parameters.
#
# @param $class	name of concrete class
# @param @handlerParams	any handler-specific parameters
#
# @return		HTTP::Daemon::Threaded::ContentParams subclass object
#*/
sub new {
	my $class = shift;
}

1;
