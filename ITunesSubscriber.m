//
//  ITunesSubscriber.m
//  AmplifierControl
//
//  Created by Joachim Chapman on 25/09/2011.
//  Copyright 2011 -2016 Joachim Chapman. All rights reserved.
//

#import "ITunesSubscriber.h"


@implementation ITunesSubscriber 

NSLock *_lock;

- (id) init {
	self = [super init];
	if (!self) return nil;
	
	_lock = [[NSLock alloc] init];
	
	[[NSDistributedNotificationCenter defaultCenter] 
	 addObserver:self 
	 selector:@selector(updateInfo:) 
	 name:@"com.apple.iTunes.playerInfo" 
	 object:nil];

	return self;
}

- (void) updateInfo:(NSNotification *) notification {
	
	NSDictionary *userInfo = [notification userInfo];
	if ([[userInfo objectForKey:@"Player State"] isEqualToString:@"Playing"]) {
		[self onPlay];
	} else {
		[self onStop];
	}
}

- (void) onPlay {
	NSLog(@"on Play");
	[_lock lock];
    @try {
        [self sendRabbitMqMessage:TRUE];
    }
    @catch (NSException *exception) {
        NSLog(exception);
    }
    @finally {
        [_lock unlock];
    }
}

- (void) onStop {
	NSLog(@"on Stop");
	[_lock lock];
    @try {
        [self sendRabbitMqMessage:FALSE];
    }
    @catch (NSException *exception) {
        NSLog(exception);
    }
    @finally {
        [_lock unlock];
    }
}

- (void) sendRabbitMqMessage: (BOOL *)isPlaying{
    
    NSURL *url = [NSURL URLWithString:@"http://10.0.0.22:15672/api/exchanges/%2f/iTunes/publish"];
    NSMutableURLRequest *request = [NSMutableURLRequest requestWithURL:url cachePolicy:NSURLRequestUseProtocolCachePolicy timeoutInterval:30.0];
    
    NSString * playCommand = @"{\"properties\":{},\"routing_key\":\"\",\"payload\":\"play\",\"payload_encoding\":\"string\"}";
    NSString * stopCommand = @"{\"properties\":{},\"routing_key\":\"\",\"payload\":\"stop\",\"payload_encoding\":\"string\"}";
    
    NSString * command;
    if (isPlaying){
        command = playCommand;
    }
    else{
        command = stopCommand;
    }
    
    NSLog(command);
    
    NSData *requestData = [command dataUsingEncoding:NSUTF8StringEncoding];
    
    [request setHTTPMethod:@"POST"];
    [request setValue:@"application/json" forHTTPHeaderField:@"content-type"];
    [request setValue:[NSString stringWithFormat:@"%lu", (unsigned long)[requestData length]] forHTTPHeaderField:@"Content-Length"];
    [request setHTTPBody: requestData];
    
    NSString *authStr = @"guest:guest";
    NSData *authData = [authStr dataUsingEncoding:NSUTF8StringEncoding];
    NSString *authValue = [NSString stringWithFormat:@"Basic %@", [authData base64EncodedStringWithOptions:NSDataBase64EncodingEndLineWithLineFeed]];
    [request setValue:authValue forHTTPHeaderField:@"Authorization"];

    
    [[NSURLConnection alloc] initWithRequest:request delegate:self];
    
}

@end
