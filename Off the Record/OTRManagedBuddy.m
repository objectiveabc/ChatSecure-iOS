//
//  OTRManagedBuddy.m
//  Off the Record
//
//  Created by Christopher Ballinger on 1/10/13.
//  Copyright (c) 2013 Chris Ballinger. All rights reserved.
//
//  This file is part of ChatSecure.
//
//  ChatSecure is free software: you can redistribute it and/or modify
//  it under the terms of the GNU General Public License as published by
//  the Free Software Foundation, either version 3 of the License, or
//  (at your option) any later version.
//
//  ChatSecure is distributed in the hope that it will be useful,
//  but WITHOUT ANY WARRANTY; without even the implied warranty of
//  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
//  GNU General Public License for more details.
//
//  You should have received a copy of the GNU General Public License
//  along with ChatSecure.  If not, see <http://www.gnu.org/licenses/>.

#import "OTRManagedBuddy.h"
#import "OTRManagedMessage.h"
#import "OTRCodec.h"
#import "OTRProtocolManager.h"
#import "NSString+HTML.h"
#import "Strings.h"
#import "OTRConstants.h"
#import "OTRXMPPManager.h"
#import "OTRManagedStatus.h"
#import "OTRManagedEncryptionStatusMessage.h"
#import "OTRManagedGroup.h"

@interface OTRManagedBuddy()
@end

@implementation OTRManagedBuddy

-(BOOL)protocolIsXMPP
{
    OTRProtocolManager * protocolManager = [OTRProtocolManager sharedInstance];
    id<OTRProtocol> protocol = [protocolManager protocolForAccount:self.account];
    if ([protocol isKindOfClass:[OTRXMPPManager class]]) {
        return YES;
    }
    return NO;
}

-(void)sendComposingChatState
{
    if([self protocolIsXMPP])
    {
        OTRProtocolManager * protocolManager = [OTRProtocolManager sharedInstance];
        OTRXMPPManager * protocol = (OTRXMPPManager *)[protocolManager protocolForAccount:self.account];
        [protocol sendChatState:kOTRChatStateComposing withBuddyID:self.objectID];
    }
}

-(void)sendActiveChatState
{
    if([self protocolIsXMPP])
    {
        OTRProtocolManager * protocolManager = [OTRProtocolManager sharedInstance];
        OTRXMPPManager * protocol = (OTRXMPPManager *)[protocolManager protocolForAccount:self.account];
        [protocol sendChatState:kOTRChatStateActive withBuddyID:self.objectID];
    }
}
-(void)sendInactiveChatState
{
    if([self protocolIsXMPP])
    {
        OTRProtocolManager * protocolManager = [OTRProtocolManager sharedInstance];
        OTRXMPPManager * protocol = (OTRXMPPManager *)[protocolManager protocolForAccount:self.account];
        [protocol sendChatState:kOTRChatStateInactive withBuddyID:self.objectID];
    }
}
-(void)invalidatePausedChatStateTimer
{
    if([self protocolIsXMPP])
    {
        OTRProtocolManager * protocolManager = [OTRProtocolManager sharedInstance];
        OTRXMPPManager * protocol = (OTRXMPPManager *)[protocolManager protocolForAccount:self.account];
        [[protocol pausedChatStateTimerForBuddyObjectID:self.objectID] invalidate];
        
    }
    
}
-(void)invalidateInactiveChatStateTimer
{
    if([self protocolIsXMPP])
    {
        OTRProtocolManager * protocolManager = [OTRProtocolManager sharedInstance];
        OTRXMPPManager * protocol = (OTRXMPPManager *)[protocolManager protocolForAccount:self.account];
        [[protocol inactiveChatStateTimerForBuddyObjectID:self.objectID] invalidate];
    }
    
}

-(void)receiveMessage:(NSString *)message
{
    //DDLogVerbose(@"received: %@",message);
    if (message) {
        self.lastMessageDisconnected = NO;
        // Strip the shit out of it, but hopefully you're talking with someone who is trusted in the first place
        // TODO: fix this so it doesn't break some cyrillic encodings
        //NSString *rawMessage = [[[message stringByConvertingHTMLToPlainText]stringByEncodingHTMLEntities] stringByLinkifyingURLs];
        NSString * rawMessage = [message stringByConvertingHTMLToPlainText];
                
        //[[NSNotificationCenter defaultCenter] postNotificationName:MESSAGE_PROCESSED_NOTIFICATION object:self];
        
        if (![[UIApplication sharedApplication] applicationState] == UIApplicationStateActive)
        {
            // We are not active, so use a local notification instead
            UILocalNotification *localNotification = [[UILocalNotification alloc] init];
            localNotification.alertAction = REPLY_STRING;
            localNotification.soundName = UILocalNotificationDefaultSoundName;
            localNotification.applicationIconBadgeNumber = [UIApplication sharedApplication].applicationIconBadgeNumber + 1;
            localNotification.alertBody = [NSString stringWithFormat:@"%@: %@",self.displayName,rawMessage];
            
            NSMutableDictionary *userInfo = [NSMutableDictionary dictionaryWithCapacity:3];
            [userInfo setObject:self.accountName forKey:kOTRNotificationUserNameKey];
            [userInfo setObject:self.account.username forKey:kOTRNotificationAccountNameKey];
            [userInfo setObject:self.account.protocol forKey:kOTRNotificationProtocolKey];
            localNotification.userInfo = userInfo;
            
            [[UIApplication sharedApplication] presentLocalNotificationNow:localNotification];
        }
    }
}

-(void)receiveChatStateMessage:(OTRChatState) newChatState
{
    self.chatStateValue = newChatState;
    //NSManagedObjectContext * context = [NSManagedObjectContext MR_contextForCurrentThread];
    //[context MR_saveToPersistentStoreAndWait];
    //[[NSNotificationCenter defaultCenter] postNotificationName:MESSAGE_PROCESSED_NOTIFICATION object:self];
}

-(void)setNewEncryptionStatus:(OTRKitMessageState)newEncryptionStatus
{
    OTRManagedEncryptionStatusMessage * currentEncryptionStatus = [self currentEncryptionStatus];
    
    /*
    if([self.messages count] > 0 && newEncryptionStatus != kOTRKitMessageStateEncrypted)
    {
        [self receiveEncryptionMessage:CONVERSATION_NOT_SECURE_WARNING_STRING];
    }
    */
    if(newEncryptionStatus != currentEncryptionStatus.statusValue)
    {
        if (newEncryptionStatus != kOTRKitMessageStateEncrypted && currentEncryptionStatus.statusValue == kOTRKitMessageStateEncrypted) {
            [[[UIAlertView alloc] initWithTitle:SECURITY_WARNING_STRING message:[NSString stringWithFormat:CONVERSATION_NO_LONGER_SECURE_STRING, self.displayName] delegate:nil cancelButtonTitle:OK_STRING otherButtonTitles:nil] show];
        }
        [OTRManagedEncryptionStatusMessage newEncryptionStatus:newEncryptionStatus buddy:self];
    }
}

-(void) newStatusMessage:(NSString *)newStatusMessage status:(OTRBuddyStatus)newStatus incoming:(BOOL)isIncoming
{
    OTRManagedStatus * currentManagedStatus = [self currentStatusMessage];
    
    if (!currentManagedStatus) {
        [OTRManagedStatus newStatus:newStatus withMessage:newStatusMessage withBuddy:self incoming:isIncoming];
        self.currentStatusValue = newStatus;
        return;
    }
    
    if (![newStatusMessage length]) {
        newStatusMessage = [OTRManagedStatus statusMessageWithStatus:newStatus];
    }
    
    //Make sure the status message is unique compared to the last status message
    if (newStatus != currentManagedStatus.statusValue || ![newStatusMessage isEqualToString:currentManagedStatus.message]) {
        
        NSPredicate * messageDateFilter = [NSPredicate predicateWithFormat:@"(date >= %@) AND (date <= %@)",currentManagedStatus.date,[NSDate date]];
        NSArray * managedMessages = [OTRManagedMessage MR_findAllWithPredicate:messageDateFilter];
        
        //if no new messages since last status update just change the most recent status
        if (![managedMessages count]) {
            [currentManagedStatus updateStatus:newStatus withMessage:newStatusMessage incoming:isIncoming];
            self.currentStatusValue = newStatus;
        }
        else
        {
            [OTRManagedStatus newStatus:newStatus withMessage:newStatusMessage withBuddy:self incoming:isIncoming];
        }
        self.currentStatusValue = newStatus;
    }
    else
    {
        self.currentStatusValue = currentManagedStatus.statusValue;
    }
}

-(OTRManagedStatus *)currentStatusMessage
{
    NSSortDescriptor * dateSort = [NSSortDescriptor sortDescriptorWithKey:@"date" ascending:NO];
    NSArray * sortedStatuses = [self.statuses sortedArrayUsingDescriptors:@[dateSort]];
    
    if ([sortedStatuses count]) {
        return [sortedStatuses firstObject];
    }
    return nil;    
}

-(OTRManagedEncryptionStatusMessage *)currentEncryptionStatus
{
    NSSortDescriptor * dateSort = [NSSortDescriptor sortDescriptorWithKey:@"date" ascending:NO];
    NSArray * sortedStatuses = [self.encryptionStatusMessages sortedArrayUsingDescriptors:@[dateSort]];
    
    if ([sortedStatuses count]) {
        return sortedStatuses[0];
    }
    return [OTRManagedEncryptionStatusMessage newEncryptionStatus:kOTRKitMessageStatePlaintext buddy:self];

    
}

-(NSInteger) numberOfUnreadMessages
{
    NSPredicate * messageFilter = [NSPredicate predicateWithFormat:@"isRead == NO AND isEncrypted == NO AND isIncoming == YES"];
    NSSet * finalSet = [self.messages filteredSetUsingPredicate:messageFilter];
    return [finalSet count];
}

- (void) allMessagesRead
{
    [self.messages setValue:[NSNumber numberWithBool:YES] forKey:@"isRead"];
    NSManagedObjectContext *context = [NSManagedObjectContext MR_contextForCurrentThread];
    [context MR_saveToPersistentStoreWithCompletion:^(BOOL success, NSError *error) {
        if (error) {
            DDLogError(@"Error saving all messages read to persistent store %@", error.userInfo);
        }
    }];
}

- (void) deleteAllMessages
{
    NSPredicate * messageFilter = [NSPredicate predicateWithFormat:@"buddy == %@",self];
    NSPredicate * notLastStatusFilter = [NSPredicate predicateWithFormat:@"self != %@",[self currentStatusMessage]];
    NSPredicate * compoundPredicate = [NSCompoundPredicate andPredicateWithSubpredicates:@[messageFilter,notLastStatusFilter]];
    
    [OTRManagedMessageAndStatus MR_deleteAllMatchingPredicate:compoundPredicate];
    NSManagedObjectContext *context = [NSManagedObjectContext MR_contextForCurrentThread];
    [context MR_saveToPersistentStoreAndWait];
}

-(void)addToGroup:(NSString *)groupName inContext:(NSManagedObjectContext *)context
{
    OTRManagedGroup * managedGroup = [OTRManagedGroup fetchOrCreateWithName:groupName inContext:context];
    [self addGroupsObject:managedGroup];
}

- (void) addToGroup:(NSString *)groupName {
    NSManagedObjectContext *context = [NSManagedObjectContext MR_contextForCurrentThread];
    [self addToGroup:groupName inContext:context];
}

-(NSArray *)groupNames
{
    NSSortDescriptor * descriptor = [[NSSortDescriptor alloc] initWithKey:OTRManagedGroupAttributes.name ascending:YES];
    return [[self.groups sortedArrayUsingDescriptors:@[descriptor]] valueForKey:OTRManagedGroupAttributes.name];
}

+(OTRManagedBuddy *)fetchOrCreateWithName:(NSString *)name account:(OTRManagedAccount *)account
{
    return [self fetchOrCreateWithName:name account:account inContext:[NSManagedObjectContext MR_contextForCurrentThread]];
}

+(OTRManagedBuddy *)fetchOrCreateWithName:(NSString *)name account:(OTRManagedAccount *)account inContext:(NSManagedObjectContext *)context
{
    OTRManagedBuddy * buddy = nil;
    OTRManagedAccount * contextAccount = [account MR_inContext:context];
    buddy = [OTRManagedBuddy fetchWithName:name account:account inContext:context];
    if (!buddy) {
        buddy = [OTRManagedBuddy MR_createInContext:context];
        buddy.accountName = name;
        buddy.account = contextAccount;
        [context MR_saveToPersistentStoreAndWait];
    }
    return buddy;
}

+(OTRManagedBuddy *)fetchWithName:(NSString *)name account:(OTRManagedAccount *)account;
{
    [self fetchWithName:name account:account inContext:[NSManagedObjectContext MR_contextForCurrentThread]];
}

+(OTRManagedBuddy *)fetchWithName:(NSString *)name account:(OTRManagedAccount *)account inContext:(NSManagedObjectContext *)context
{
    OTRManagedAccount * contextAccount = [account MR_inContext:context];
    NSPredicate * accountPredicate = [NSPredicate predicateWithFormat:@"%K == %@",OTRManagedBuddyRelationships.account,contextAccount];
    NSPredicate * usernamePredicate = [NSPredicate predicateWithFormat:@"%K == %@",OTRManagedBuddyAttributes.accountName,name];
    
    NSArray * filteredArray = [OTRManagedBuddy MR_findAllWithPredicate:[NSCompoundPredicate andPredicateWithSubpredicates:@[usernamePredicate,accountPredicate]]];
    
    if([filteredArray count])
    {
        OTRManagedBuddy * buddy =  [filteredArray firstObject];
        return [buddy MR_inContext:context];
    }
    return nil;
}

@end
