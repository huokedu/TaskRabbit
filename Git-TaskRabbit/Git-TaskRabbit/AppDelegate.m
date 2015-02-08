#import "AppDelegate.h"
#import "EventsViewController.h"
#import "GitHubEventData.h"

@interface AppDelegate ()

@property (nonatomic) NSManagedObjectContext *managedObjectContext;
@property (nonatomic) NSManagedObjectModel *managedObjectModel;
@property (nonatomic) NSPersistentStoreCoordinator *persistentStoreCoordinator;

-(void)buildManagedObjects;
-(void)removeDeletedEvents:(NSArray*)githubObjects shouldSave:(BOOL)save;
-(NSManagedObject*)doesEventExist:(NSString*)predicate;
-(NSArray*)removeUnmatchedObjects:(NSArray*)source;
-(void)applyGitHubObject:(GitHubEventData*)data
                 toEvent:(NSManagedObject*)event
          withIdentifier:(NSNumber*)identifier;
@end

@implementation AppDelegate

// Entry point into the app, create the main window and also build/retrieve all
// managed objects as well as their dependent icons
- (BOOL)application:(UIApplication *)application didFinishLaunchingWithOptions:(NSDictionary *)launchOptions {
    
    // add any of the event types that we are concerned with
    // TODO: remove pushEvent
    _matchEvents = [NSArray arrayWithObjects:
                    [GitHubEventData watchEventStr],
                    [GitHubEventData forkEventStr],
                    nil];
    
    // enable use of custom font
    self.octiconsFont = [UIFont fontWithName:@"octicons" size:32];
    // builds the list of managed objects and identify
    // all icons that need to be downloaded (we also remove
    // duplicates from the imageURLS to prevent multiple downloads
    // of the same image.
    [self buildManagedObjects];
    
    // Make the startup view controller and begin navigation
    EventsViewController *controller = [[EventsViewController alloc] initWithNibName:@"EventsViewController" bundle:nil];
    self.window = [[UIWindow alloc] initWithFrame:[UIScreen mainScreen].bounds];
    self.window.rootViewController = [[UINavigationController alloc] initWithRootViewController:controller];
    [self.window makeKeyAndVisible];
    
    return YES;
}

// When the app is exiting, save the database
- (void)applicationWillTerminate:(UIApplication *)application {
    [self saveContext];
}

#pragma mark - Core Data stack

// Get the URL for where to save data
- (NSURL *)applicationDocumentsDirectory {
    return [[[NSFileManager defaultManager] URLsForDirectory:NSDocumentDirectory inDomains:NSUserDomainMask] lastObject];
}

// Managed object model
- (NSManagedObjectModel *)managedObjectModel {
    if (_managedObjectModel != nil) {
        return _managedObjectModel;
    }
    NSURL *modelURL = [[NSBundle mainBundle] URLForResource:@"Git_TaskRabbit" withExtension:@"momd"];
    _managedObjectModel = [[NSManagedObjectModel alloc] initWithContentsOfURL:modelURL];
    return _managedObjectModel;
}

// Persistent store coordinator
- (NSPersistentStoreCoordinator *)persistentStoreCoordinator {
    if (_persistentStoreCoordinator != nil) {
        return _persistentStoreCoordinator;
    }
    
    _persistentStoreCoordinator = [[NSPersistentStoreCoordinator alloc] initWithManagedObjectModel:[self managedObjectModel]];
    NSURL *storeURL = [[self applicationDocumentsDirectory] URLByAppendingPathComponent:@"Git_TaskRabbit.sqlite"];
    NSError *error = nil;
    NSString *failureReason = @"There was an error creating or loading the application's saved data.";
    if (![_persistentStoreCoordinator addPersistentStoreWithType:NSSQLiteStoreType configuration:nil URL:storeURL options:nil error:&error]) {
        NSMutableDictionary *dict = [NSMutableDictionary dictionary];
        dict[NSLocalizedDescriptionKey] = @"Failed to initialize the application's saved data";
        dict[NSLocalizedFailureReasonErrorKey] = failureReason;
        dict[NSUnderlyingErrorKey] = error;
        error = [NSError errorWithDomain:@"YOUR_ERROR_DOMAIN" code:9999 userInfo:dict];
        NSLog(@"Unresolved error %@, %@", error, [error userInfo]);
    }
    
    return _persistentStoreCoordinator;
}

// Managed object context
- (NSManagedObjectContext *)managedObjectContext {
    if (_managedObjectContext != nil) {
        return _managedObjectContext;
    }
    
    NSPersistentStoreCoordinator *coordinator = [self persistentStoreCoordinator];
    if (!coordinator) {
        return nil;
    }
    _managedObjectContext = [[NSManagedObjectContext alloc] init];
    [_managedObjectContext setPersistentStoreCoordinator:coordinator];
    return _managedObjectContext;
}

#pragma mark - Core Data Saving support

// Save the database
- (void)saveContext {
    NSManagedObjectContext *managedObjectContext = self.managedObjectContext;
    if (managedObjectContext != nil) {
        NSError *error = nil;
        if ([managedObjectContext hasChanges] && ![managedObjectContext save:&error]) {
            NSLog(@"Unresolved error %@, %@", error, [error userInfo]);
        }
    }
}

#pragma mark - Other Utility Functions

// Build the list of managed objects
-(void)buildManagedObjects
{
    // process array of returned objects and create managed objects from these
    // values taking advantage of the entity for the model
    NSArray* arr = [self fetchGitHubSourceData];
    
    // remove all events from the database that no longer
    // appear within the  GitHub results
    [self removeDeletedEvents:arr shouldSave:YES];
    
    // remove all objects returned from GitHUb
    // that don't match the 'Event' type we are looking for
    arr = [self removeUnmatchedObjects:arr];
    
    // Iterate over all github objects returned
    for (GitHubEventData* ghobj in arr)
    {
        // NOTE:
        // As a method to determine the validity of the GitHub object
        // and whether we need to track it or not, we search for an event that
        // matches our 'identifier' query
        
        // Retrieve the long 'identifier' value to make our comparisons
        NSNumberFormatter* formatter = [[NSNumberFormatter alloc] init];
        [formatter setNumberStyle:NSNumberFormatterDecimalStyle];
        NSNumber* identifier = [formatter numberFromString:[ghobj.primaryData objectForKey:@"id"]];
        
        // With the identifier value that we just retrieved, lets search the currently
        // stored objects to see if we have any with a matching 'identifier' value.
        // If we do have a match then we want to update the repo data as that may have
        // changed
        NSManagedObject* selectedEvent = [self doesEventExist:
                                          [NSString stringWithFormat:@"identifier = %@", identifier]];
        
        // if the query returned no event, then we know that no event exists for
        // the current identifier that we are evaluating.... So, we allocate
        // a new object to save in the database
        if (selectedEvent == nil) {
            selectedEvent = [NSEntityDescription
                             insertNewObjectForEntityForName:@"Event"
                             inManagedObjectContext:[self managedObjectContext]];
            
            // If we get here then we are creating a new 'Event' object
            // and we need further information on the github object
            [ghobj requestFurtherDetails];
        }
        
        // update the details saved on the github object
        [self applyGitHubObject:ghobj toEvent:selectedEvent withIdentifier:identifier];
    }
    
    // NOTE: no need in specifying the store that this managed object belngs to
    // as there is only 1 store that we are using for this app and that store
    // gets linked to the object when we save the context below...
    
    // save now that we have built our store
    [self saveContext];
}

// Fetches the guthub data from the web
-(NSArray*)fetchGitHubSourceData
{
    // retrieves the base github event data to work with
    return [GitHubEventData requestGitHubEventData];
}

// Retrieve all event type managed objects that satisfy the
// predicate passed in
-(NSArray*)fetchEvents:(NSString*)formattedPredicate
{
    // Create a fetch request object to lookup stored objects
    NSManagedObjectContext* moc = [self managedObjectContext];
    NSEntityDescription* entDesc = [NSEntityDescription entityForName:@"Event"
                                               inManagedObjectContext:moc];
    NSFetchRequest* request = [[NSFetchRequest alloc] init];
    [request setEntity:entDesc];
    
    // only gather certain objects based on predicate string, if we have
    // a valid value, otherwise there is no predicate and we will just
    // return all objects
    if (![formattedPredicate isEqualToString:@""]) {
        NSPredicate *predicate = [NSPredicate predicateWithFormat:formattedPredicate];
        [request setPredicate:predicate];
    }
    
    // sort objects by repo name
    NSSortDescriptor *sortDescriptor = [[NSSortDescriptor alloc] initWithKey:@"repoName" ascending:YES];
    [request setSortDescriptors:@[sortDescriptor]];
    
    // return the list of objects
    return [moc executeFetchRequest:request error:NULL];
}

// Simple helper function that validates whether or not we have any entries
// matching the predicate/query passed in
-(NSManagedObject*)doesEventExist:(NSString*)predicate
{
    // Run query against currently stored events
    NSArray* currentEvents = [self fetchEvents:predicate];
    return currentEvents != nil && [currentEvents count] > 0 ? currentEvents[0] : nil;
}

// This has the job of removing any events from storage
// that are no longer stored within the GitHub data
-(void)removeDeletedEvents:(NSArray*)githubObjects shouldSave:(BOOL)save
{
    BOOL deletedAnObject = NO;
    NSArray* events = [self fetchEvents:@""];
    for (NSManagedObject* obj in events) {
        
        // the event id to search for within the
        long eventIdentifier = [[obj valueForKey:@"identifier"] longValue];
        
        // fast enumerte over the array to check if the 'Event' in question
        // should stil be stored in the database
        __block NSInteger foundIndex = NSNotFound;
        [githubObjects enumerateObjectsUsingBlock:^(id githubObj, NSUInteger idx, BOOL *stop) {
            
            // cast to our type
            GitHubEventData* data = (GitHubEventData*)githubObj;
            
            // get the event id to compare against
            NSNumberFormatter* formatter = [[NSNumberFormatter alloc] init];
            [formatter setNumberStyle:NSNumberFormatterDecimalStyle];
            NSNumber* identifier = [formatter numberFromString:[data.primaryData objectForKey:@"id"]];
            
            // we also want to check that we still support the event type
            BOOL matchedEvent = [_matchEvents containsObject:
                                 [GitHubEventData stringForGitHubType:(GitHubType)[obj valueForKey:@"type"]]];
            
            // we can stop the enumeration when we find a matching id
            if ([identifier longValue] == eventIdentifier && matchedEvent == YES) {
                foundIndex = idx;
                *stop = YES;
            }
        }];
        
        // delete the object if we could not find a match
        // within the source data that we retrieved from git-hub
        if (foundIndex == NSNotFound) {
            deletedAnObject = YES;
            [[self managedObjectContext] deleteObject:obj];
        }
    }
    
    // Should we save now... or will that happen elsewhere
    if (save == YES && deletedAnObject == YES) {
        [self saveContext];
    }
}

// Removes any and all irrelevant objects returned from GitHUb
// that we do not care about as we make our iteration
-(NSArray*)removeUnmatchedObjects:(NSArray*)source
{
    NSPredicate* matchPredicate =
    [NSPredicate predicateWithBlock: ^BOOL(GitHubEventData* githubObj, NSDictionary *bindings) {
        NSString* eventType = [githubObj.primaryData objectForKey:@"type"];
        return [_matchEvents containsObject:eventType];
    }];
    return [source filteredArrayUsingPredicate:matchPredicate];
}

// updates the event with the data contained in the github event data passed in
-(void)applyGitHubObject:(GitHubEventData*)data
                 toEvent:(NSManagedObject*)event
          withIdentifier:(NSNumber*)identifier
{
    // Get all values from the 'GitHub' object that we care about
    NSString* timeStamp = [data.primaryData objectForKey:@"created_at"];
    NSString* eventType = [data.primaryData objectForKey:@"type"];
    GitHubType gitHubType = [GitHubEventData gitHubTypeFromString:eventType];
    NSDate* eventDate = [GitHubEventData getDateForTimestamp:timeStamp];
    
    // Build repo details object to add to 'Event' object
    NSMutableDictionary* repoDetails = [NSMutableDictionary dictionary];
    [repoDetails setValue:[data.repoData objectForKey:@"name"] forKey:@"repoName"];
    [repoDetails setValue:[GitHubEventData getDateForTimestamp:
                           [data.repoData objectForKey:@"created_at"]] forKey:@"repoDate"];
    [repoDetails setValue:[data.repoData objectForKey:@"language"] forKey:@"repoLanguage"];
    [repoDetails setValue:data.watchers forKey:@"watchers"];
    [repoDetails setValue:data.forks forKey:@"forks"];
    [repoDetails setValue:[NSNumber numberWithInt:(int)gitHubType] forKey:@"repoAction"];
    
    // build the managed object
    [event setValue:eventDate forKey:@"timeStamp"];
    [event setValue:[data.actorData objectForKey:@"name"] forKey:@"userName"];
    [event setValue:[data.repoData objectForKey:@"name"] forKey:@"repoName"];
    [event setValue:[data.actorData objectForKey:@"avatar_url"] forKey:@"avatarURL"];
    [event setValue:[NSNumber numberWithInt:(int)gitHubType] forKey:@"type"];
    [event setValue:[NSNumber numberWithLong:[identifier longValue]] forKey:@"identifier"];
    [event setValue:repoDetails forKey:@"repoDetails"];
}

@end
