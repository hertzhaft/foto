package FotoJSON;
use Mojo::Base 'Mojolicious';

# This method will run once at server start
sub startup {
  my $self = shift;

  # Documentation browser under "/perldoc"
  $self->plugin('Config', file => 'foto_json.conf');

  # helpers
  $self->helper(db => sub {
  	my ($c, $key) = @_;
  	my $dbname = $c->config->{db};
  	state $db = Mojo::SQLite->new("sqlite:$dbname")->db;
  	return $db;
  	});

  # Router
  my $r = $self->routes;

  # Normal route to controller
  $r->get('/')->to('example#welcome');
}

1;
