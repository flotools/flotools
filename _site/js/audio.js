function playing(player) {
    label = player.id;
    time = player.currentTime;
    if (time == 0) {
        ga('send', 'event', 'Media', 'Play', label);
    } else {
        ga('send', 'event', 'Media', 'Play', label+' @ ' + time);
    }
}

function pausing(player) {
    label = player.id;
    time = player.currentTime;
    if (player.getDuration() - time != 0) {
        ga('send', 'event', 'Media', 'Pause', label+' @ ' + time);
    }
}

function ending(player) {
    label = player.id;
    ga('send', 'event', 'Media', 'Finished', label);
}
