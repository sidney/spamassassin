# <@LICENSE>
# Copyright 2004 Apache Software Foundation
# 
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
# 
#     http://www.apache.org/licenses/LICENSE-2.0
# 
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.
# </@LICENSE>

=head1 NAME

Mail::SpamAssassin::Plugin - SpamAssassin plugin base class

=head1 SYNOPSIS

  package MyPlugin;

  use Mail::SpamAssassin::Plugin;
  use vars qw(@ISA);
  @ISA = qw(Mail::SpamAssassin::Plugin);

  sub new {
    my $class = shift;
    my $mailsaobject = shift;
    
    # the usual perlobj boilerplate to create a subclass object
    $class = ref($class) || $class;
    my $self = $class->SUPER::new($mailsaobject);
    bless ($self, $class);
   
    # then register an eval rule
    $self->register_eval_rule ("check_for_foo");

    # and return the new plugin object
    return $self;
  }

  ...methods...

  1;

=head1 DESCRIPTION

This is the base class for SpamAssassin plugins; all plugins must be objects
that implement this class.

This class provides no-op stub methods for all the callbacks that a plugin
can receive.  It is expected that your plugin will override one or more
of these stubs to perform its actions.

SpamAssassin implements a plugin chain; each callback event is passed to each
of the registered plugin objects in turn.  Any plugin can call
C<$plugin->inhibit_further_callbacks()> to block delivery of that event to
later plugins in the chain.  This is useful if the plugin has handled the
event, and there will be no need for later plugins to handle it as well.

The following methods can be overridden by subclasses to handle events
that SpamAssassin will call back to:

=head1 INTERFACE

=over 4

=cut

package Mail::SpamAssassin::Plugin;
use Mail::SpamAssassin;

use strict;
use bytes;

use vars qw{
  @ISA $VERSION
};

@ISA = qw();
$VERSION = 'bogus';

###########################################################################

=item $plugin = MyPluginClass->new ($mailsaobject)

Constructor.  Plugins that need to register themselves will need to
define their own; the default super-class constructor will work fine
for plugins that just override a method.

Note that subclasses must provide the C<$mailsaobject> to the
superclass constructor, like so:

  my $self = $class->SUPER::new($mailsaobject);

=cut

sub new {
  my $class = shift;
  my $mailsaobject = shift;
  $class = ref($class) || $class;

  if (!defined $mailsaobject) {
    die "plugin: usage: Mail::SpamAssassin::Plugin::new(class,mailsaobject)";
  }

  my $self = {
    main => $mailsaobject,
    _inhibit_further_callbacks => 0
  };
  bless ($self, $class);
  $self;
}

=item $plugin->parse_config ( { options ... } )

Parse a configuration line that hasn't already been handled.  C<options>
is a reference to a hash containing these options:

=over 4

=item line

The line of configuration text to parse.   This has leading and trailing
whitespace, and comments, removed.

=item user_config

A boolean: C<1> if reading a user's configuration, C<0> if reading the
system-wide configuration files.

=back

If the configuration line was a setting that is handled by this plugin, the
method implementation should call C<$plugin->inhibit_further_callbacks()> and
return C<1>.

If the setting is not handled by this plugin, the method should return C<0> so
that a later plugin may handle it, or so that SpamAssassin can output a warning
message to the user if no plugin understands it.

Note that it is suggested that configuration be stored on the
C<Mail::SpamAssassin::Conf> object in use, instead of the plugin object itself.
That can be found as C<$plugin->{main}->{conf}>.

=cut

sub parse_config {
  my ($self, $opts) = @_;
  # implemented by subclasses, no-op by default
  return 0;
}

=item $plugin->finish ()

Called when the C<Mail::SpamAssassin> object is destroyed.

=cut

sub finish {
  my ($self) = @_;
  # implemented by subclasses, no-op by default
}

###########################################################################

=back

=head1 HELPER APIS

These methods provide an API for plugins to register themselves
to receive specific events, or control the callback chain behaviour.

=over 4

=item $plugin->register_eval_rule ($nameofevalsub)

Plugins that implement an eval test will need to call this, so that
SpamAssassin calls into the object when that eval test is encountered.

For example,

  $plugin->register_eval_rule ('check_for_foo')

will cause C<$plugin->check_for_foo()> to be called for this
SpamAssassin rule:

  header   FOO_RULE	eval:check_for_foo()

Note that eval rules are passed the following arguments:

=over 4

=item The plugin object itself

=item The C<Mail::SpamAssassin::PerMsgStatus> object calling the rule

=item any and all arguments specified in the configuration file

=back

In other words, the eval test method should look something like this:

  sub check_for_foo {
    my ($self, $permsgstatus, ...arguments...) = @_;
    ...code returning 0 or 1
  }

Note that the headers can be accessed using the C<get()> method on the
C<Mail::SpamAssassin::PerMsgStatus> object, and the body by
C<get_decoded_stripped_body_text_array()> and other similar methods.
Similarly, the C<Mail::SpamAssassin::Conf> object holding the current
configuration may be accessed through C<$permsgstatus->{main}->{conf}>.

The eval rule should return C<1> for a hit, or C<0> if the rule
is not hit.

State for a single message being scanned should be stored on the C<$checker>
object, not on the C<$self> object, since C<$self> persists between scan
operations.

=cut

sub register_eval_rule {
  my ($self, $nameofsub) = @_;
  $self->{main}->{conf}->register_eval_rule ($self, $nameofsub);
}

=item $plugin->inhibit_further_callbacks()

Tells the plugin handler to inhibit calling into other plugins in the plugin
chain for the current callback.  Frequently used when parsing configuration
settings using C<parse_config()>.

=cut

sub inhibit_further_callbacks {
  my ($self) = @_;
  $self->{_inhibit_further_callbacks} = 1;
}

=item dbg ($message)

Output a debugging message C<$message>, if the SpamAssassin object is running
with debugging turned on.

=cut

sub dbg { Mail::SpamAssassin::dbg (@_); }

1;

=back

=head1 SEE ALSO

C<Mail::SpamAssassin>

C<Mail::SpamAssassin::PerMsgStatus>

http://bugzilla.spamassassin.org/show_bug.cgi?id=2163

=cut
