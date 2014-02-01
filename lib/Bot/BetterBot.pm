package Bot::BetterBot;

our $VERSION = 0.01;

use strict;
use warnings;

use Carp;
use File::Spec;
use Try::Tiny;
use Moose;
use namespace::autoclean;
use Readonly;
use Text::Wrap;
use DBI;
use POE qw/Component::IRC/;

has server          => (is => 'ro', isa => 'Str', required => 1);
has username        => (is => 'ro', isa => 'Str', default => 'betterbot');
has nick            => (is => 'ro', isa => 'Str', default => 'betterbot');
has real_name       => (is => 'ro', isa => 'Str', default => 'Better Bot');
has port            => (is => 'ro', isa => 'Int', default => 6667);
has ssl             => (is => 'ro', isa => 'Int', default => 0);
has quit_msg        => (is => 'ro', isa => 'Str', default => q/I'll show myself out./);
has channels        => (is => 'ro', isa => 'ArrayRef[Str]', default => sub { [] });
has default_plugins => (is => 'ro', isa => 'ArrayRef[Str]', default => sub { [qw/Loader/] });
has password        => (is => 'ro', isa => 'Maybe[Str]');
has dsn             => (is => 'ro', isa => 'Maybe[Str]');
has db_username     => (is => 'ro', isa => 'Maybe[Str]');
has db_password     => (is => 'ro', isa => 'Maybe[Str]');

has store => (
   is      => 'ro',
   isa     => 'HashRef',
   default => sub { {} },
   traits  => ['Hash'],
   handles => {
      set_var    => 'set',
      get_var    => 'get',
      delete_var => 'delete',
   },
);

has irc => (
   is       => 'ro',
   isa      => 'POE::Component::IRC',
   init_arg => undef,
   writer   => '_set_irc',
);

has loaded_plugins => (
   is       => 'ro',
   isa      => 'HashRef[Bot::BetterBot::Plugin]',
   traits   => ['Hash'],
   init_arg => undef,
   handles  => {
      _add_plugin    => 'set',
      _remove_plugin => 'delete',
      plugin         => 'get',
      is_loaded      => 'exists',
      plugins        => 'values'
   }
);
   
Readonly my $MAX_LENGTH => 400;
Readonly my $ALIAS      => "betterbot$$";


# after construction, load all plugins specified in config
sub BUILD {
   my $self = shift;
   foreach my $p (@{$self->default_plugins}) {
      try { $self->load($p); } catch { print "ERROR: Plugin $p failed to load: $_\n"; };
   }
}



sub run {
   my $self = shift;

   # TODO: switch to POE::Component::IRC::State to avoid having to do manual channel tracking
   $self->_set_irc(POE::Component::IRC->spawn(
      alias    => $ALIAS,
      Server   => $self->server,
      Port     => $self->port,
      Password => $self->password,
      Nick     => $self->nick,
      Username => $self->username,
      Ircname  => $self->real_name,
      UseSSL   => $self->ssl,
      useipv6  => 1,
   ));
   
   POE::Session->create(
      inline_states => {
         _start           => sub { $self->_on_start(@_)      },
         irc_001          => sub { $self->_on_connect(@_)    },
         irc_public       => sub { $self->_on_msg(@_)        },
         irc_msg          => sub { $self->_on_msg(@_)        },
         irc_ctcp_action  => sub { $self->_on_emote(@_)      },
         irc_notice       => sub { $self->_on_notice(@_)     },
         irc_disconnected => sub { $self->_on_disconnect(@_) },
         irc_error        => sub { $self->_on_error(@_)      },
         irc_join         => sub { $self->_on_join(@_)       },
         irc_part         => sub { $self->_on_part(@_)       },
         irc_kick         => sub { $self->_on_kick(@_)       },
         irc_nick         => sub { $self->_on_nick(@_)       },
         irc_quit         => sub { $self->_on_quit(@_)       },
         irc_topic        => sub { $self->_on_topic(@_)      },
         irc_whois        => sub { $self->_on_whois(@_)      },
         irc_shutdown     => sub { $self->_on_shutdown(@_)   },
      },
   );

   $poe_kernel->run();
}


sub db {
   my $self = shift;
   croak 'Cannot connect to database: no dsn was specified in config' unless $self->dsn;

   my $dbh = DBI->connect(
      $self->dsn, $self->db_username, $self->db_password, { RaiseError => 1 }
   ) or croak "Failed to connect to database using DSN $self->dsn: $DBI::errstr";
   
   return $dbh;
}
   

### IRC Commands ###

sub say {
   my ($self, $args) = @_;
   
   croak q/A nonempty message body is required for argument 'body'/ unless $args->{body};
   croak q/A channel name or 'msg' is required for argument 'channel'/ unless $args->{channel};
   if ($args->{channel} eq 'msg') {
      croak q/A nick is required for argument 'nick'/ unless $args->{nick};
   }

   # if bot was prefixed (eg: 'botname: foo bar') prepend user's nick to our response
   my $body = ($args->{channel} ne 'msg' and $args->{prefix} and $args->{nick})
      ? "$args->{nick}: $args->{body}"
      : $args->{body};     

   my $dest = _get_dest($args);

   # partition our response into multiple messages if message body exceeds MAX_LENGTH
   local $Text::Wrap::columns = $MAX_LENGTH;
   local $Text::Wrap::unexpand = 0;
   my $wrapped = Text::Wrap::wrap('', '...', $body);
   my @queue = split(/\n+/, $wrapped);

   $self->irc->yield(privmsg => $dest, $_) foreach (@queue);
}


sub reply {
   my ($self, $args, $response) = @_;
   
   croak q/A nonempty message body is required for argument 'body'/ unless $args->{body};
   croak q/A nonempty message body is required for argument 'response'/ unless $response;
   croak q/A channel name or 'msg' is required for argument 'channel'/ unless $args->{channel};
   if ($args->{channel} eq 'msg') {
      croak q/A nick is required for argument 'nick'/ unless $args->{nick};
   }
   
   # create local copy of $args, don't want to modify caller's hashref
   my %r = %$args;
   $r{body} = $response;
   
   $self->say(\%r);
}


sub emote {
   my ($self, $args) = @_;
   
   croak q/A nonempty message body is required for argument 'body'/ unless $args->{body};
   croak q/A channel name or 'msg' is required for argument 'channel'/ unless $args->{channel};
   if ($args->{channel} eq 'msg') {
      croak q/A nick is required for argument 'nick'/ unless $args->{nick};
   }

   my $dest = _get_dest($args);
   my $body = _truncate($args->{body}); 

   $self->irc->yield(ctcp => $dest, "ACTION $body");
}


sub notice {
   my ($self, $args) = @_;

   croak q/A nonempty message body is required for argument 'body'/ unless $args->{body};
   croak q/A channel name or 'msg' is required for argument 'channel'/ unless $args->{channel};
   if ($args->{channel} eq 'msg') {
      croak q/A nick is required for argument 'nick'/ unless $args->{nick};
   }
   
   my $dest = _get_dest($args);
   my $body = _truncate($args->{body}); 
   
   $self->irc->yield(notice => $dest, $body);
}


sub channel_info {
   my $self = shift;
   #TODO: implement this
}


sub join {
   my ($self, $args) = @_;
   croak 'A channel must be specified' unless $args->{channel};
   print "Joining $args->{channel}\n";
   $self->irc->yield(join => $args->{channel});
}


sub part {
   my ($self, $args) = @_;
   croak 'A channel must be specified' unless $args->{channel};
   print "Parting $args->{channel}\n";
   $self->irc->yield(part => $args->{channel});
}


sub kick {
   my ($self, $args) = @_;
   my $msg = $args->{msg};

   croak 'A channel must be specified' unless $args->{channel};
   croak 'A nick must be specified' unless $args->{nick};
   
   $self->irc->yield(kick => $args->{channel}, $args->{nick}, _truncate($msg));
}


sub mode {
   my ($self, $args) = @_;
   croak 'A mode string must be specified' unless $args->{mode};
   $self->irc->yield(mode => $args->{mode});
}


sub oper {
   my ($self, $args) = @_;
   croak 'A username is required' unless $args->{username};
   croak 'A password is required' unless $args->{password};
   $self->irc->yield(oper => $args->{username}, $args->{password});
}


sub whois {
   my ($self, $nick) = @_;
   croak 'A nick is required' unless $nick;
   $self->irc->yield(whois => $nick);
}


sub connect {
   my $self = shift;
   print 'Connecting to ', $self->server, ' ', ($self->ssl ? '+' : ''), $self->port, ' ',
      ($self->password || ''), "\n";
   $self->irc->yield(connect => {});
}

sub quit {
   my ($self, $args) = @_;
   $self->irc->yield(quit => _truncate($args->{msg}));
}



### Plugin Handling ###

sub load {
   my ($self, $name) = @_;

   die "A plugin name is required.\n" unless $name;
   die "Plugin $name is already loaded.\n" if $self->is_loaded(lc($name));

   # Since we are dynamically loading arbitrary code, we try to do the Right Thing (TM)
   # as much as possible here...
   
   # we don't want people to !load ../../../etc/passwd
   $name =~ s|/||g;
   
   # try to load the plugin's module
   my ($volume, $directory, $file) = File::Spec->splitpath(__FILE__);
   die "No plugin with that name is currently installed.\n" unless -e "$volume$directory"."BetterBot/Plugin/$name.pm";
   
   my $filename = "Bot/BetterBot/Plugin/$name.pm";

   try { require $filename; } catch { 
      print "Could not load plugin '$name': $_\n";
      die "An error occurred importing the module. Check logs..\n";
   };

   my $plugin = "Bot::BetterBot::Plugin::$name"->new({
      bot  => $self,
      name => $name,
   });

   # ensure we get back a Bot::BetterBot::Plugin with the exepcted name
   die "Module's new() method did not return an object.\n" unless ($plugin and ref($plugin));
   die "Module's new() method didn't return the type I was expecting.\n" unless ref($plugin) =~ /\Q$name/;

   # invoke plugin's on_load method
   $plugin->on_load;
   
   # At this point, we've constructed the plugin, and it's on_load method didn't throw
   # an exception, so we add the plugin to our loaded_plugins hash
   $self->_add_plugin(lc($name), $plugin);
   
   print "Loaded plugin $name.\n";
   return $plugin;
}


sub unload {
   my ($self, $name) = @_;

   die "Plugin name required.\n" unless $name;
   die "Plugin $name not loaded.\n" unless $self->is_loaded(lc($name));

   # invoke plugin's on_unload method, but continue with unload if exception is thrown
   try { $self->plugin(lc($name))->on_unload; } catch { $self->_plugin_err($name, 'on_unload', $_); };
   
   $self->_remove_plugin(lc($name));
   print "Unloaded plugin $name.\n";
}


sub reload {
   my ($self, $name) = @_;
   
   die "Plugin name required.\n" unless $name;
   
   $self->unload($name);
   return $self->load($name);
}



### IRC Event Callbacks ###

# when the POE session starts, connect to the IRC server
sub _on_start {
   my $self = shift;
   $self->irc->yield(register => 'all');
   $self->connect;
}

# once a connection is established, join all channels defined in config
sub _on_connect {
   my $self = shift;
   $self->join({channel => $_}) foreach (@{$self->channels});
}

# For each IRC event, iterate through loaded_plugins and invoke each plugin's
# appropriate event handler. All plugin methods are non-fatal; if a plugin method
# throws an exception, a detailed error will be logged to STDOUT, but only a generic
# error string will be sent back to IRC. In any case, the bot will continue running.
# If the method returns a value, it will be sent to the corresponding channel or user.

sub _on_msg {
   my $self = shift;
   my @args = @_[ARG0, ARG1, ARG2];
   my $msg = $self->_process_msg(@args);

   foreach my $p ($self->plugins) {
      try {
         my $response = $p->on_msg($msg);
         $self->reply($msg, $response) if $response;
      } catch { $self->_plugin_err($p->name, 'on_msg', $_, _get_dest($msg)); };
   }
}


sub _on_emote {
   my $self = shift;
   my @args = @_[ARG0, ARG1, ARG2];
   my $msg = $self->_process_msg(@args);
   
   foreach my $p ($self->plugins) {
      try { 
         my $response = $p->on_emote($msg); 
         $self->reply($msg, $response) if $response;
      } catch { $self->_plugin_err($p->name, 'on_emote', $_, _get_dest($msg)); };
   }
}


sub _on_notice {
   my $self = shift;
   my @args = @_[ARG0, ARG1, ARG2];
   my $msg = $self->_process_msg(@args);
   
   foreach my $p ($self->plugins) {
      try { 
         my $response = $p->on_notice($msg); 
         $self->reply($msg, $response) if $response;
      } catch { $self->_plugin_err($p->name, 'on_notice', $_, _get_dest($msg)); };
   }
}


sub _on_join {
   my $self = shift;
   my ($mask, $channel) = @_[ARG0, ARG1];

   foreach my $p ($self->plugins) {
      try {
         my $response = $p->on_join({
            mask    => $mask,
            nick    => _get_nick($mask),
            channel => $channel,
         });
         $self->say({body => $response, channel => $channel}) if $response;
      } catch { $self->_plugin_err($p->name, 'on_join', $_, $channel); };
   }
}


sub _on_part {
   my $self = shift;
   my ($mask, $channel, $msg) = @_[ARG0, ARG1, ARG2];

   foreach my $p ($self->plugins) {
      try {
         my $response = $p->on_part({
            mask    => $mask,
            nick    => _get_nick($mask),
            channel => $channel,
            msg     => $msg,
         });
         $self->say({body => $response, channel => $channel}) if $response;
      } catch { $self->_plugin_err($p->name, 'on_part', $_, $channel); };
   }
}


sub _on_kick {
   my $self = shift;
   my ($kicker_mask, $channel, $kickee_mask, $msg) = @_[ARG0, ARG1, ARG2, ARG3];

   foreach my $p ($self->plugins) {
      try {
         my $response = $p->on_kick({
            kicker_mask => $kicker_mask,
            kickee_mask => $kickee_mask,
            kicker_nick => _get_nick($kicker_mask),
            kickee_nick => _get_nick($kickee_mask),
            channel     => $channel,
            msg         => $msg,
         });
         $self->say({body => $response, channel => $channel}) if $response;
      } catch { $self->_plugin_err($p->name, 'on_kick', $_, $channel); };
   }
}


sub _on_nick {
   my $self = shift;
   my ($mask, $new_nick) = @_[ARG0, ARG1];

   foreach my $p ($self->plugins) {
      try {
         $p->on_nick({
            mask     => $mask,
            nick     => _get_nick($mask),
            new_nick => $new_nick,
         });
      } catch { $self->_plugin_err($p->name, 'on_nick', $_); };
   }
}


sub _on_quit {
   my $self = shift;
   my ($mask, $msg) = @_[ARG0, ARG1];
   
   foreach my $p ($self->plugins) {
      try {
         $p->on_quit({
            mask => $mask,
            nick => _get_nick($mask),
            msg  => $msg,
         });
      } catch { $self->_plugin_err($p->name, 'on_quit', $_); };
   }
}


sub _on_topic {
   my $self = shift;
   my ($mask, $channel, $topic) = @_[ARG0, ARG1, ARG2];

   foreach my $p ($self->plugins) {
      try {
         my $response = $p->on_topic({
            mask    => $mask,
            nick    => _get_nick($mask),
            channel => $channel,
            topic   => $topic,
         });
         $self->say({body => $response, channel => $channel}) if $response;
      } catch { $self->_plugin_err($p->name, 'on_topic', $_, $channel); };
   }
}


sub _on_whois {
   my $self = shift;
   my $whois = $_[ARG0];
   # TODO: implement this
}


sub _on_disconnect {
   my $self = shift;
   # connection to server lost
   # TODO: either cleanup here and shutdown, or retry connection
}

sub _on_error {
   my $self = shift;
   my $msg = $_[ARG0];
   print "ERROR: IRC server says '$msg'\n";
   # TODO: we are probably about to be disconnected, so perform cleanup
}

sub _on_shutdown {
   my $self = shift;
   # TODO: IRC going down, perform cleanup and exit
}



### Helper Subroutines ###

# returns the nick from a 'nick!user@host' hostmask
sub _get_nick {
   return (split /!/, shift)[0];
}


# returns the recipient's nick if it's a private message,
# else returns the channel name
sub _get_dest {
   my $msg = shift; 
   return $msg->{channel} eq 'msg' ? $msg->{nick} : $msg->{channel};
}


# returns the given string truncated to MAX_LENGTH. If an empty string
# is provided, returns undef
sub _truncate {
   my $body = shift;
   return (length($body) > $MAX_LENGTH ? substr($body, 0, $MAX_LENGTH) : $body) if $body;
   return undef;
}


# given the standard POE args MASK, CHANNEL, and BODY, returns a hashref:
#    mask    => sender's hostmask,
#    nick    => sender's nick
#    channel => channel name or 'msg' if privmsg
#    prefix  => string we were prefixed with (eg 'betterbot:') or undef
#    body    => body of message, with prefix removed
sub _process_msg {
   my ($self, $mask, $channel, $body) = @_;
   my $own_nick = $self->nick;

   return {   
      mask    => $mask,
      nick    => _get_nick($mask),
      channel => $channel->[0] eq lc($self->nick) ? 'msg' : $channel->[0],
      prefix  => ($body =~ s/^(\Q$own_nick\E\s*[:,-]?)\s*//i) ? $1 : undef,
      body    => $body =~ s/^\s+|\s+$//rg,
   };
}


# logs an error msg $msg in method $method of plugin $name to STDOUT,
# prints error msg to appropriate channel
sub _plugin_err {
   my ($self, $name, $method, $msg, $channel) = @_;
   print "ERROR: Exception in plugin '$name' in method '$method': $msg\n";
   if ($channel) {
      $self->irc->yield(privmsg => $channel, "Error occurred in plugin '$name' in method '$method'. Check logs.") 
   }
}



__PACKAGE__->meta->make_immutable;

1;
