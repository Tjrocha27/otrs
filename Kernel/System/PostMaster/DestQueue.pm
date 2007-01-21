# --
# Kernel/System/PostMaster/DestQueue.pm - sub part of PostMaster.pm
# Copyright (C) 2001-2007 OTRS GmbH, http://otrs.org/
# --
# $Id: DestQueue.pm,v 1.19 2007-01-21 01:26:10 mh Exp $
# --
# This software comes with ABSOLUTELY NO WARRANTY. For details, see
# the enclosed file COPYING for license information (GPL). If you
# did not receive this file, see http://www.gnu.org/licenses/gpl.txt.
# --

package Kernel::System::PostMaster::DestQueue;

use strict;

use vars qw($VERSION);
$VERSION = '$Revision: 1.19 $';
$VERSION =~ s/^.*:\s(\d+\.\d+)\s.*$/$1/;

sub new {
    my $Type = shift;
    my %Param = @_;

    # allocate new hash for object
    my $Self = {};
    bless ($Self, $Type);

    $Self->{Debug} = $Param{Debug} || 0;

    # get needed opbjects
    foreach (qw(ConfigObject LogObject DBObject ParseObject QueueObject)) {
        $Self->{$_} = $Param{$_} || die "Got no $_!";
    }

    return $Self;
}
# GetQueueID
sub GetQueueID {
    my $Self = shift;
    my %Param = @_;
    my $Queue = $Self->{ConfigObject}->Get('PostmasterDefaultQueue');
    my %GetParam = %{$Param{Params}};
    my $QueueID;
    # get all system addresses
    my %SystemAddresses = $Self->{DBObject}->GetTableData(
        Table => 'system_address',
        What => 'value0, queue_id',
        Valid => 1
    );
    # check possible to, cc and resent-to emailaddresses
    my $Recipient = '';
    foreach (qw(Cc To Resent-To)) {
        if ($GetParam{$_}) {
            if ($Recipient) {
                $Recipient .= ', ';
            }
            $Recipient .= $GetParam{$_};
        }
    }
    # get addresses
    my @EmailAddresses = $Self->{ParseObject}->SplitAddressLine(
        Line => $Recipient,
    );
    # check addresses
    foreach (@EmailAddresses) {
        my $Address = $Self->{ParseObject}->GetEmailAddress(Email => $_);
        foreach (keys %SystemAddresses) {
            if ($_ =~ /^\Q$Address\E$/i) {
                if ($Self->{Debug} > 1) {
                    $Self->{LogObject}->Log(
                        Priority => 'debug',
                        Message => "Match email: $_ (QueueID=$SystemAddresses{$_}/MessageID:$GetParam{'Message-ID'})!",
                    );
                }
                $QueueID = $SystemAddresses{$_};
            }
            else {
                if ($Self->{Debug} > 1) {
                    $Self->{LogObject}->Log(
                        Priority => 'debug',
                        Message => "Does not match email: $_ (QueueID=$SystemAddresses{$_}/MessageID:$GetParam{'Message-ID'})!",
                    );
                }
            }
        }
    }
    if (!$QueueID) {
        return $Self->{QueueObject}->QueueLookup(Queue => $Queue) || 1;
    }
    else {
        return $QueueID;
    }
}
# GetTrustedQueueID
sub GetTrustedQueueID {
    my $Self = shift;
    my %Param = @_;
    my %GetParam = %{$Param{Params}};
    my $QueueID;
    my $Queue;
    # if there exists a X-OTRS-Queue header
    if ($GetParam{'X-OTRS-Queue'}) {
        if ($Self->{Debug} > 0) {
            $Self->{LogObject}->Log(
                Priority => 'debug',
                Message => "There exists a X-OTRS-Queue header: $GetParam{'X-OTRS-Queue'} (MessageID:$GetParam{'Message-ID'})!",
            );
        }
        # get dest queue
        return $Self->{QueueObject}->QueueLookup(Queue => $GetParam{'X-OTRS-Queue'});
    }
    else {
        return;
    }
}

1;