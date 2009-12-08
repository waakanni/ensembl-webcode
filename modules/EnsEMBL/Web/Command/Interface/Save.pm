package EnsEMBL::Web::Command::Interface::Save;

use strict;
use warnings;

use EnsEMBL::Web::RegObj;

use base qw(EnsEMBL::Web::Command);

sub process {
  my $self = shift;
  my $object = $self->object;
  my $interface = $object->interface;
  my $url = '/'.$interface->script_name.'/';

  my $param = {
    '_referer' => $object->param('_referer'),
  };

  $interface->cgi_populate($object);
  ## Add user ID to new entries in the user/group_record tables
  if (!$object->param('id') && ref($interface->data) =~ /Record/) {
    my $user = $EnsEMBL::Web::RegObj::ENSEMBL_WEB_REGISTRY->get_user;
    $interface->data->user_id($user->id);
  }

  my $success = $interface->data->save;
  my $type;
  if ($success) {
    $param->{'id'} = $success;
    if (my $custom = $interface->get_landing_page) {
      $url = $custom;
    }
    else {
      $url .= 'List';
    }
  }
  else {
    $url .= 'Problem';
  }

  $self->ajax_redirect($url, $param);
}

1;
