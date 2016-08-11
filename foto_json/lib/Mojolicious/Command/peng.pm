# --------------------
package Mojolicious::Command::peng;
# --------------------
use Getopt::Long qw(GetOptionsFromArray :config no_auto_abbrev no_ignore_case);
use Mojo::Base 'Mojolicious::Command';
use Mojo::SQLite;
use Mojo::SQLite::Transaction;
use File::Find qw(find);
use Image::ExifTool;
use DDP;

has description => 'Create PENG database';
has usage       => "Usage: foto_json peng dbname\n";

my $exifTool = Image::ExifTool->new;

my @tags = qw(
    FileName
    FileAccessDate
    FileModifyDate
    FilePermissions
    FileSize
    FileType
    FileTypeExtension
    ImageWidth
    ImageHeight
    Megapixels
    ImageSize
    MIMEType
    BitDepth
    Orientation
    CopyrightNotice
    DateCreated
    ModifyDate
    );

sub sql_insert {
  my ($db, $table) = @_;
  my $table_info = $db->query("PRAGMA table_info($table)");
  my $fields = $table_info->arrays->map(sub { $_->[1] });
  my $placeholders = $fields->map( sub { '?' })->join(', ');
  return "INSERT INTO $table VALUES ($placeholders)";
}

sub import {
  my ($app, $db, $table, $base, $dir) = @_;
  $app->log->debug("importing '$cat'");
  my ($path, $re, $cat, $text) = @$dir;
  my $sql = sql_insert($db);
  my $count = 0;
  my $tx = $db->begin;
  my $wanted = sub {
  	return unless /$re/;
  	$exifTool->ImageInfo($File::Find::name);
  	my $info = $exifTool->GetInfo(@tags);
  	my @content = (undef, $cat, $File::Find::dir, map { $info->{$_} } @tags);
  	my $res = $db->query($sql, @content);
  	say "DB error: $_" if $res->sth->err;
  	say $_ if $ENV{PENG_VERBOSE};
  	$tx->commit unless $count++ % 1000;
  	};
  find($wanted, "$base$path");
  $tx->commit;
}

sub run {
  my ($self, @args) = @_;
	GetOptionsFromArray(\@args, 'v|verbose' => \$ENV{PENG_VERBOSE});
  my $app = $self->app;
  my $config = $app->config;
  my $dbname = $config->{db};
  die "No database name in config" unless $dbname;
  my $sql = Mojo::SQLite->new("file:$dbname")
  	->options({sqlite_allow_multiple_statements => 1, autocommit => 0})
	or die "Could not create $dbname";
  my $migrations = $sql->migrations->from_data(__PACKAGE__, 'migrations.sql');
  $migrations->migrate(0)->migrate(1);
  $db->query("PRAGMA default_cache_size=200000");
  import($app, $sql->db, $config->{table}, $config->{bhbase}, $_) for @{$config->{bhdirs}};
  $app->log->debug("database '$dbname' created");
};

1;

__DATA__
@@ migrations.sql
-- 1 up
CREATE TABLE files (
  ID INTEGER PRIMARY KEY AUTOINCREMENT,
  cat TEXT NOT NULL,
  FilePath TEXT NOT NULL,
  FileName TEXT NOT NULL,
  FileAccessDate TEXT,
  FileModifyDate TEXT,
  FilePermissions TEXT,
  FileSize TEXT,
  FileType TEXT,
  FileTypeExtension TEXT,
  ImageWidth INTEGER,
  ImageHeight INTEGER,
  Megapixels REAL,
  ImageSize TEXT,
  MIMEType TEXT,
  BitDepth TEXT,
  Orientation TEXT,
  CopyrightNotice TEXT,
  DateCreated TEXT,
  ModifyDate TEXT
  );

CREATE INDEX x_filepath ON files (FilePath);
CREATE INDEX x_filename ON files (FileName);

-- 1 down
DROP TABLE IF EXISTS files;
