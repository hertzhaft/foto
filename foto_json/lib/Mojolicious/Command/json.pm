# --------------------
package Mojolicious::Command::json;
# --------------------
use Mojo::Base 'Mojolicious::Command';
use JSON;
use Mojo::SQLite;
use Tie::IxHash;
use DDP;

has description => 'Create JSON from SQLite db';
has usage       => "Usage: foto_json json /path/to/objects.sqlite\n";

my $LABEL = {
	ART => 'artists',
	SCL => 'artists',
	PER => 'persons',
	PHAROS_TITLE => 'title',
	# PHAROS_CATEGORY =>  
	# INH => 'description',
	DAT => 'dates',
	LOC => 'locations',
	MUS => 'locations',
	# PHAROS_REPRO => 'images',
	NEG => 'images',
	SUB => 'objectType',
	INV => 'inventory',
	TEC => 'medium',
	# TST => 'test',
	# FHK => 'photographers',
	# FDT => 'photodate',
	DIM => 'dimensions',
};
my $SKIP = qr/COL|FHK|FDT|INV|JOB|KRZ|LIT|INH/;

# https://github.com/jeresig/pharos-images/wiki/Artwork-Metadata-Format

sub run {
  open (OBJ, ">objects.log") or die $!;
  open (IMG, ">images.log") or die $!;
  open (COPY_IM, ">copyimages.cmd") or die $!;
  open (COPY_PL, ">copyplates.cmd") or die $!;
  open (COPY_FI, ">copyfilms.cmd") or die $!;
  open (COPY_BH, ">copyphotos.cmd") or die $!;
  open (COPY_EX, ">copyeximages.cmd") or die $!;
  open (COPY_ON, ">copyonofrio.cmd") or die $!;
  open (COPY_GE, ">copygernsheim.cmd") or die $!;
  open (TEST, ">test.log") or die $!;
  my ($self, $dbname) = @_;
  my $app = $self->app;
  # connect to database
  $dbname ||= $app->config->{db};
  die "No database name" unless $dbname;
  my $sql = Mojo::SQLite->new("file:$dbname")
  	->options({sqlite_allow_multiple_statements => 1})
	or die "Could not open $dbname";
  $app->log->debug("db '$dbname' opened");
  my $parts = $app->db->query('SELECT obj, part, GROUP_CONCAT(fotoid) as ids FROM foto GROUP BY part')->hashes;
  #  LIMIT 1000
  my $result = [];
  $parts->each( sub {
    my ($obj, $part, $fotoids) = @{$_}{qw(obj part ids)};
    my $entry = {};
    my $t_entry = tie(%$entry, 'Tie::IxHash', id => "obj$obj", lang => 'de', url => "http://foto.biblhertz.it/obj$part"); 
    push @$result, $entry;
    my @ids = split(',', $fotoids);
    my $placeholders = join(',', ('?') x @ids);
  	# for each obj/part, construct a query using all fotoids
  	my $lines = $app->db->query("SELECT cat, name FROM content WHERE fotoid in ($placeholders) GROUP BY cat, name", @ids)->hashes;
  	$lines->each( sub {
  		my ($cat, $name) = @{$_}{qw(cat name)};
  		return if $cat =~ $SKIP;
  		$cat = 'DIM' if (($cat eq 'TEC' && $name =~ /\d+ x \d+/) or ($cat eq 'TEC' && $name =~ /mm|cm/));
  		# translate cat into label, insert content line into entry
  		my $c = $entry->{$LABEL->{$cat} || $cat} ||= [];
  		print TEST "$name\n" if $cat =~ /TEC/;
  		return push @$c, { name => $name } if $cat =~ /ART|SCL|MUS/;
  		return push @$c, { city => $name } if $cat =~ /LOC/;
  		# if ($cat =~ /PHAROS_REPRO/)
  		if ($cat =~ /NEG/) {
  			return unless $name =~ /^bh[A-Za-z0-9\-]+$/;
  			print OBJ "obj$part;$name\n";
  			print IMG "$name\n" unless $name !~ /^bh/;
  			print COPY_IM "xcopy /s $name.* R:\\TEMP\\pharos\\\n" unless $name !~ /^bhim/;
  			print COPY_PL "xcopy /s $name.* R:\\TEMP\\pharos\\\n" unless $name !~ /^bhp/;
  			print COPY_FI "xcopy /s $name.* R:\\TEMP\\pharos\\\n" unless $name !~ /^bhf/;
  			print COPY_BH "xcopy /s $name.* R:\\TEMP\\pharos\\\n" unless $name !~ /^bh[0-9]/;
  			print COPY_ON "xcopy /s $name.* R:\\TEMP\\pharos\\\n" unless $name !~ /^bhon/;
  			print COPY_EX "xcopy /s $name.* R:\\TEMP\\pharos\\\n" unless $name !~ /^bhex/;
  			print COPY_GE "xcopy /s $name.* R:\\TEMP\\pharos\\\n" unless $name !~ /^bhge/;
			# return unless $name !~ /.tif/;
			return push @$c, "$name.jpg";
  			}
  		if ($cat =~ /DAT/) {
  			my ($from, $to) = ($name =~  /(\d+)\D*(\d+)?/);
  			$from += 0;
  			$to += 0;
  			return push @$c, {
  				label => $name,
  				start => $from,
  				end => $to || $from,
  				circa => $name =~ /\?|um|vor|nach/ ? JSON::true : JSON::false,
  				};
  			}
  		$name =~ s/\n//g; 
  		push @$c, $name;
	  	});
	# p $entry unless $entry->{title};
	$entry->{title} = exists $entry->{title} ? join('; ', @{$entry->{title}}) : '(none)';
	$entry->{medium} = join('; ', @{$entry->{medium}}) if exists $entry->{medium};
	$entry->{objectType} = join('; ', @{$entry->{objectType}}) if exists $entry->{objectType};
	$t_entry->Reorder(qw(id url lang images title objectType dates artists dimensions locations categories medium));
  	});
  print JSON->new->utf8->pretty->encode($result);
}

1;

