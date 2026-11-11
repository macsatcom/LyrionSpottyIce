use strict; use warnings;
use Test::More;
use lib 't/lib';
require './SpottyIce/Entity.pm';
my $E = 'Plugins::SpottyIce::Entity';
my $tr = { uri=>'spotify:track:1', entity_type=>'track', decorations=>{
  identity=>{name=>'Song'}, parent=>{entity=>{decorations=>{identity=>{name=>'Alb'}}}},
  creators=>[{entity=>{decorations=>{identity=>{name=>'A'}}}},{entity=>{decorations=>{identity=>{name=>'B'}}}}],
  visual_identity=>{cover=>[{url=>'s',size=>'small'},{url=>'x',size=>'xlarge'},{url=>'l',size=>'large'}]},
  playback=>{duration_ms=>123000} } };
no strict 'refs';
sub f { my $n=shift; &{"${E}::$n"}(@_) }
is f('name',$tr),'Song'; is f('name',{uri=>'u'}),'u'; is f('name',undef),'';
is f('creators',$tr),'A, B'; is f('creators',{}),'';
is f('parentName',$tr),'Alb'; ok !defined f('parentName',{});
is f('cover',$tr),'l';
is f('cover',{decorations=>{visual_identity=>{cover=>[{url=>'s',size=>'small'},{url=>'d',size=>'default'}]}}}),'d';
is f('cover',{decorations=>{visual_identity=>{cover=>[{url=>'a',size=>'small'},{url=>'b',size=>'small'}]}}}),'b';
ok !defined f('cover',{});
is f('durationSecs',$tr),123; ok !defined f('durationSecs',{});
ok f('isPlayable',$tr); ok !f('isPlayable',{entity_type=>'album'});
ok f('isContainer',{entity_type=>'show'}); ok !f('isContainer',$tr);
my $cb = sub {}; my $pcb = sub {};
is_deeply f('toItem',$tr,$cb), {name=>'Song',line1=>'Song',line2=>'A, B',image=>'l',type=>'audio',
  url=>'spottyice://spotify:track:1',duration=>123,on_select=>'play',playall=>1};
is_deeply f('toItem',{uri=>'spotify:album:2',entity_type=>'album'},$cb,$pcb),
  {name=>'spotify:album:2',type=>'playlist',url=>$cb,passthrough=>[{uri=>'spotify:album:2',name=>'spotify:album:2'}],playlist=>$pcb};
ok !exists f('toItem',{uri=>'spotify:album:2',entity_type=>'album'},$cb)->{playlist}, 'no playlist without play callback';
is f('toItem',{uri=>'spotify:episode:3',entity_type=>'episode',decorations=>{parent=>{entity=>{decorations=>{identity=>{name=>'Show'}}}}}},$cb)->{line2},'Show';
ok !defined f('toItem',{uri=>'x',entity_type=>'ad'},$cb);
ok !defined f('toItem',{entity_type=>'track'},$cb);
ok !defined f('toItem',undef,$cb);
is f('linkToUri','spotify:track:6TYQ'),'spotify:track:6TYQ';
is f('linkToUri',' https://open.spotify.com/playlist/37i9?si=abc '),'spotify:playlist:37i9';
is f('linkToUri','https://open.spotify.com/intl-da/artist/2yEw'),'spotify:artist:2yEw';
is f('linkToUri','open.spotify.com/episode/0ct3'),'spotify:episode:0ct3';
ok !defined f('linkToUri','https://example.com/album/1'); ok !defined f('linkToUri','spotify:user:x'); ok !defined f('linkToUri',undef);
done_testing;
