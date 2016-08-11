# --------------------
package Mojolicious::Command::xml;
# --------------------
use Getopt::Long qw(GetOptionsFromArray :config no_auto_abbrev no_ignore_case);
use Mojo::Base 'Mojolicious::Command';
use Mojo::SQLite;
use Path::Tiny qw(path);
use DDP;

has description => 'Export XML from PENG database';
has usage       => "Usage: foto_json xml\n";

sub export {
  my ($app, $db, $table, $base, $dir) = @_;
  my ($path, $re, $cat, $text) = @$dir;
  my $file = "./$cat.xml";
  my $sql = "SELECT FilePath, FileName FROM $table WHERE cat = ?";
  my $res = $db->query($sql, $cat);
  my $files = $res->arrays;
  my $size = $files->size;
  path($file)->spew_utf8(
  	qq|<?xml version="1.0" encoding="utf-8"?>\n|,
  	qq|<files count="$size" name="$cat" info="$text" path="$path">\n|,
  	$files->map(sub {
  		qq|<img path="$_->[0]">$_->[1]</img>\n|
  		})->each,
  	qq|</files>\n|,
  	);
  $app->log->debug("file '$cat.xml' exported");
}

sub run {
  my ($self, @args) = @_;
	GetOptionsFromArray(\@args, 'v|verbose' => \$ENV{PENG_VERBOSE});
  my $app = $self->app;
  my $config = $app->config;
  my $dbname = $config->{db};
  die "No database name in config" unless $dbname;
  my $sql = Mojo::SQLite->new("file:$dbname")
  	->options({sqlite_allow_multiple_statements => 1})
	or die "Could not open $dbname";
  export($app, $sql->db, $config->{table}, $config->{bhbase}, $_) for @{$config->{bhdirs}};
  $app->log->debug("database '$dbname' exported");
};

1;
