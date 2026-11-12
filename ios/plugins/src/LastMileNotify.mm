// Last Mile daily reminders: a Godot iOS plugin with no Godot API at all.
//
// The game (scripts/notify.gd) writes the schedule to user://lastmile_notify.json, which on iOS is in the
// app's Documents folder. This watches that file and, whenever it changes, replaces our pending local
// notifications (ids starting "lm.") with the ones it lists. If the file says "ask": true and iOS hasn't
// asked the player yet, it shows the permission prompt (while the app is in front).
//
// Godot's export calls last_mile_notify_init() at startup (see LastMileNotify.gdip).

#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>
#import <UserNotifications/UserNotifications.h>

static NSString *const kFileName = @"lastmile_notify.json";
static NSString *const kPrefix = @"lm.";

@interface LMNotify : NSObject
@property(nonatomic, strong) NSTimer *timer;
@property(nonatomic, copy) NSString *path;
@property(nonatomic, strong) NSDate *seen;      // modification date of the file last acted on
@property(nonatomic, strong) NSDictionary *plan; // its contents
@property(nonatomic) BOOL asking;
@end

@implementation LMNotify

+ (instancetype)shared {
	static LMNotify *one;
	static dispatch_once_t once;
	dispatch_once(&once, ^{ one = [LMNotify new]; });
	return one;
}

- (void)start {
	dispatch_async(dispatch_get_main_queue(), ^{
		NSNotificationCenter *nc = [NSNotificationCenter defaultCenter];
		for (NSNotificationName n in @[ UIApplicationDidBecomeActiveNotification, UIApplicationWillResignActiveNotification,
					UIApplicationDidEnterBackgroundNotification ]) {
			[nc addObserver:self selector:@selector(poke) name:n object:nil];
		}
		self.timer = [NSTimer scheduledTimerWithTimeInterval:2.0 target:self selector:@selector(tick) userInfo:nil repeats:YES];
		[self tick];
	});
}

- (void)poke {
	// The game rewrites the file as it goes to the background; give it a moment to land.
	dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.5 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{ [self tick]; });
	[self tick];
}

// Godot's user:// on iOS is Documents. Look there first, then (once) anywhere likely under the app's folders.
- (NSString *)findFile {
	NSFileManager *fm = [NSFileManager defaultManager];
	if (self.path && [fm fileExistsAtPath:self.path]) {
		return self.path;
	}
	NSMutableArray<NSString *> *roots = [NSMutableArray array];
	for (NSNumber *d in @[ @(NSDocumentDirectory), @(NSApplicationSupportDirectory), @(NSLibraryDirectory) ]) {
		NSString *r = NSSearchPathForDirectoriesInDomains((NSSearchPathDirectory)d.integerValue, NSUserDomainMask, YES).firstObject;
		if (r) {
			[roots addObject:r];
		}
	}
	for (NSString *r in roots) {
		NSString *p = [r stringByAppendingPathComponent:kFileName];
		if ([fm fileExistsAtPath:p]) {
			return self.path = p;
		}
	}
	for (NSString *r in roots) {
		NSDirectoryEnumerator *e = [fm enumeratorAtPath:r];
		NSString *rel;
		while ((rel = [e nextObject])) {
			if (e.level > 5) {
				[e skipDescendants];
				continue;
			}
			if ([rel.lastPathComponent isEqualToString:kFileName]) {
				return self.path = [r stringByAppendingPathComponent:rel];
			}
		}
	}
	return nil;
}

- (void)tick {
	NSString *p = [self findFile];
	if (!p) {
		return;
	}
	NSDate *mod = [[NSFileManager defaultManager] attributesOfItemAtPath:p error:nil].fileModificationDate;
	if (mod && self.seen && [mod isEqualToDate:self.seen]) {
		[self maybeAsk];
		return;
	}
	NSData *data = [NSData dataWithContentsOfFile:p];
	id json = data ? [NSJSONSerialization JSONObjectWithData:data options:0 error:nil] : nil;
	if (![json isKindOfClass:[NSDictionary class]]) {
		return; // half-written: try again next tick
	}
	self.seen = mod;
	self.plan = json;
	NSLog(@"[LastMileNotify] schedule changed: %lu item(s), ask=%@", (unsigned long)[json[@"items"] count], json[@"ask"]);
	[self apply];
	[self maybeAsk];
}

- (void)maybeAsk {
	if (self.asking || ![self.plan[@"ask"] boolValue] ||
			[UIApplication sharedApplication].applicationState != UIApplicationStateActive) {
		return;
	}
	UNUserNotificationCenter *c = [UNUserNotificationCenter currentNotificationCenter];
	self.asking = YES;
	[c getNotificationSettingsWithCompletionHandler:^(UNNotificationSettings *s) {
		if (s.authorizationStatus != UNAuthorizationStatusNotDetermined) {
			// Asked before (iOS only ever shows the prompt once). Nothing to do until the next change.
			dispatch_async(dispatch_get_main_queue(), ^{ self.asking = s.authorizationStatus != UNAuthorizationStatusNotDetermined; });
			return;
		}
		[c requestAuthorizationWithOptions:(UNAuthorizationOptionAlert | UNAuthorizationOptionSound)
						 completionHandler:^(BOOL granted, NSError *error) {
							 NSLog(@"[LastMileNotify] permission %@", granted ? @"granted" : @"declined");
							 if (granted) {
								 dispatch_async(dispatch_get_main_queue(), ^{ [self apply]; });
							 }
						 }];
	}];
}

// Replace our pending notifications with the plan's.
- (void)apply {
	NSArray *items = [self.plan[@"items"] isKindOfClass:[NSArray class]] ? self.plan[@"items"] : @[];
	UNUserNotificationCenter *c = [UNUserNotificationCenter currentNotificationCenter];
	[c getNotificationSettingsWithCompletionHandler:^(UNNotificationSettings *s) {
		UNAuthorizationStatus st = s.authorizationStatus;
		BOOL allowed = st == UNAuthorizationStatusAuthorized || st == UNAuthorizationStatusProvisional;
		if (@available(iOS 14.0, *)) {
			allowed = allowed || st == UNAuthorizationStatusEphemeral;
		}
		[c getPendingNotificationRequestsWithCompletionHandler:^(NSArray<UNNotificationRequest *> *pending) {
			NSMutableArray *ours = [NSMutableArray array];
			for (UNNotificationRequest *r in pending) {
				if ([r.identifier hasPrefix:kPrefix]) {
					[ours addObject:r.identifier];
				}
			}
			[c removePendingNotificationRequestsWithIdentifiers:ours];
			if (!allowed) {
				NSLog(@"[LastMileNotify] not allowed to notify (status %ld); cleared %lu", (long)st, (unsigned long)ours.count);
				return;
			}
			NSUInteger added = 0;
			for (NSDictionary *it in items) {
				if (![it isKindOfClass:[NSDictionary class]] || ![it[@"id"] isKindOfClass:[NSString class]]) {
					continue;
				}
				NSDateComponents *when = [NSDateComponents new];
				when.year = [it[@"year"] integerValue];
				when.month = [it[@"month"] integerValue];
				when.day = [it[@"day"] integerValue];
				when.hour = [it[@"hour"] integerValue];
				when.minute = [it[@"minute"] integerValue];
				NSDate *date = [[NSCalendar currentCalendar] dateFromComponents:when];
				if (!date || date.timeIntervalSinceNow <= 0) {
					continue;
				}
				UNMutableNotificationContent *content = [UNMutableNotificationContent new];
				content.title = [it[@"title"] description] ?: @"";
				content.body = [it[@"body"] description] ?: @"";
				content.sound = [UNNotificationSound defaultSound];
				content.threadIdentifier = @"lm.daily";
				UNCalendarNotificationTrigger *trigger = [UNCalendarNotificationTrigger triggerWithDateMatchingComponents:when repeats:NO];
				UNNotificationRequest *req = [UNNotificationRequest requestWithIdentifier:it[@"id"] content:content trigger:trigger];
				[c addNotificationRequest:req
					withCompletionHandler:^(NSError *error) {
						if (error) {
							NSLog(@"[LastMileNotify] couldn't schedule %@: %@", req.identifier, error);
						}
					}];
				added++;
			}
			NSLog(@"[LastMileNotify] scheduled %lu (replaced %lu)", (unsigned long)added, (unsigned long)ours.count);
		}];
	}];
}

@end

void last_mile_notify_init() {
	[[LMNotify shared] start];
}

void last_mile_notify_deinit() {
}
