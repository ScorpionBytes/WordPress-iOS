#import "PostHelper.h"
#import "WordPress-Swift.h"

@import WordPressKit;

@implementation PostHelper

+ (void)updatePost:(AbstractPost *)post withRemotePost:(RemotePost *)remotePost inContext:(NSManagedObjectContext *)context {
    NSNumber *previousPostID = post.postID;
    post.postID = remotePost.postID;
    // Used to populate author information for self-hosted sites.
    BlogAuthor *author = [post.blog getAuthorWithId:remotePost.authorID];

    post.author = remotePost.authorDisplayName ?: author.displayName;
    post.authorID = remotePost.authorID;
    post.date_created_gmt = remotePost.date;
    post.dateModified = remotePost.dateModified;
    post.postTitle = remotePost.title;
    post.permaLink = [remotePost.URL absoluteString];
    post.content = remotePost.content;
    post.status = remotePost.status;
    post.password = remotePost.password;

    if (remotePost.postThumbnailID != nil) {
        post.featuredImage = [Media existingOrStubMediaWithMediaID: remotePost.postThumbnailID inBlog:post.blog];
    } else {
        post.featuredImage = nil;
    }

    post.pathForDisplayImage = remotePost.pathForDisplayImage;
    if (post.pathForDisplayImage.length == 0) {
        [post updatePathForDisplayImageBasedOnContent];
    }
    post.authorAvatarURL = remotePost.authorAvatarURL ?: author.avatarURL;
    post.mt_excerpt = remotePost.excerpt;
    post.wp_slug = remotePost.slug;
    post.suggested_slug = remotePost.suggestedSlug;

    if ([remotePost.revisions wp_isValidObject]) {
        post.revisions = [remotePost.revisions copy];
    }

    if (remotePost.postID != previousPostID) {
        [self updateCommentsForPost:post];
    }

    post.autosaveTitle = remotePost.autosave.title;
    post.autosaveExcerpt = remotePost.autosave.excerpt;
    post.autosaveContent = remotePost.autosave.content;
    post.autosaveModifiedDate = remotePost.autosave.modifiedDate;
    post.autosaveIdentifier = remotePost.autosave.identifier;

    if ([post isKindOfClass:[Page class]]) {
        Page *pagePost = (Page *)post;
        pagePost.parentID = remotePost.parentID;
    } else if ([post isKindOfClass:[Post class]]) {
        Post *postPost = (Post *)post;
        postPost.commentCount = remotePost.commentCount;
        postPost.likeCount = remotePost.likeCount;
        postPost.postFormat = remotePost.format;
        postPost.tags = [remotePost.tags componentsJoinedByString:@","];
        postPost.postType = remotePost.type;
        postPost.isStickyPost = (remotePost.isStickyPost != nil) ? remotePost.isStickyPost.boolValue : NO;
        [self updatePost:postPost withRemoteCategories:remotePost.categories inContext:context];

        NSString *publicID = nil;
        NSString *publicizeMessage = nil;
        NSString *publicizeMessageID = nil;
        NSMutableDictionary *disabledPublicizeConnections = [NSMutableDictionary dictionary];
        if (remotePost.metadata) {
            NSDictionary *latitudeDictionary = [self dictionaryWithKey:@"geo_latitude" inMetadata:remotePost.metadata];
            NSDictionary *longitudeDictionary = [self dictionaryWithKey:@"geo_longitude" inMetadata:remotePost.metadata];
            NSDictionary *geoPublicDictionary = [self dictionaryWithKey:@"geo_public" inMetadata:remotePost.metadata];
            if (latitudeDictionary && longitudeDictionary) {
                NSNumber *latitude = [latitudeDictionary numberForKey:@"value"];
                NSNumber *longitude = [longitudeDictionary numberForKey:@"value"];
                CLLocationCoordinate2D coord;
                coord.latitude = [latitude doubleValue];
                coord.longitude = [longitude doubleValue];
                publicID = [geoPublicDictionary stringForKey:@"id"];
            }
            NSDictionary *publicizeMessageDictionary = [self dictionaryWithKey:@"_wpas_mess" inMetadata:remotePost.metadata];
            publicizeMessage = [publicizeMessageDictionary stringForKey:@"value"];
            publicizeMessageID = [publicizeMessageDictionary stringForKey:@"id"];

            NSArray *disabledPublicizeConnectionsArray = [self entriesWithKeyLike:@"_wpas_skip_*" inMetadata:remotePost.metadata];
            for (NSDictionary *disabledConnectionDictionary in disabledPublicizeConnectionsArray) {
                NSString *dictKey = [disabledConnectionDictionary stringForKey:@"key"];
                // We only want to keep the keyringID value from the key
                NSNumber *keyringConnectionID = @([[dictKey stringByReplacingOccurrencesOfString:@"_wpas_skip_"
                                                                                      withString:@""]integerValue]);
                NSMutableDictionary *keyringConnectionData = [NSMutableDictionary dictionaryWithCapacity:2];
                keyringConnectionData[@"id"] = [disabledConnectionDictionary stringForKey:@"id"];
                keyringConnectionData[@"value"] = [disabledConnectionDictionary stringForKey:@"value"];
                disabledPublicizeConnections[keyringConnectionID] = keyringConnectionData;
            }
        }
        postPost.publicID = publicID;
        postPost.publicizeMessage = publicizeMessage;
        postPost.publicizeMessageID = publicizeMessageID;
        postPost.disabledPublicizeConnections = disabledPublicizeConnections;
    }

    post.statusAfterSync = post.status;
}

- (RemotePost *)remotePostWithPost:(AbstractPost *)post
{
    RemotePost *remotePost = [RemotePost new];
    remotePost.postID = post.postID;
    remotePost.date = post.date_created_gmt;
    remotePost.dateModified = post.dateModified;
    remotePost.title = post.postTitle ?: @"";
    remotePost.content = post.content;
    remotePost.status = post.status;
    if (post.featuredImage) {
        remotePost.postThumbnailID = post.featuredImage.mediaID;
    }
    remotePost.password = post.password;
    remotePost.type = @"post";
    remotePost.authorAvatarURL = post.authorAvatarURL;
    // If a Post's authorID is 0 (the default Core Data value)
    // or nil, don't send it to the API.
    if (post.authorID.integerValue != 0) {
        remotePost.authorID = post.authorID;
    }
    remotePost.excerpt = post.mt_excerpt;
    remotePost.slug = post.wp_slug;

    if ([post isKindOfClass:[Page class]]) {
        Page *pagePost = (Page *)post;
        remotePost.parentID = pagePost.parentID;
        remotePost.type = @"page";
    }
    if ([post isKindOfClass:[Post class]]) {
        Post *postPost = (Post *)post;
        remotePost.format = postPost.postFormat;
        remotePost.tags = [[postPost.tags componentsSeparatedByString:@","] wp_map:^id(NSString *obj) {
            return [obj stringByTrimmingCharactersInSet:NSCharacterSet.whitespaceCharacterSet];
        }];
        remotePost.categories = [self remoteCategoriesForPost:postPost];
        remotePost.metadata = [self remoteMetadataForPost:postPost];

        // Because we can't get what's the self-hosted non Jetpack site capabilities
        // only Admin users are allowed to set a post as sticky.
        // This doesn't affect WPcom sites.
        //
        BOOL canMarkPostAsSticky = ([post.blog supports:BlogFeatureWPComRESTAPI] || post.blog.isAdmin);
        remotePost.isStickyPost = canMarkPostAsSticky ? @(postPost.isStickyPost) : nil;
    }

    remotePost.isFeaturedImageChanged = post.isFeaturedImageChanged;

    return remotePost;
}

- (NSArray *)remoteCategoriesForPost:(Post *)post
{
    return [[post.categories allObjects] wp_map:^id(PostCategory *category) {
        return [self remoteCategoryWithCategory:category];
    }];
}

- (RemotePostCategory *)remoteCategoryWithCategory:(PostCategory *)category
{
    RemotePostCategory *remoteCategory = [RemotePostCategory new];
    remoteCategory.categoryID = category.categoryID;
    remoteCategory.name = category.categoryName;
    remoteCategory.parentID = category.parentID;
    return remoteCategory;
}

- (NSArray *)remoteMetadataForPost:(Post *)post {
    NSMutableArray *metadata = [NSMutableArray arrayWithCapacity:4];

    if (post.publicID) {
        NSMutableDictionary *publicDictionary = [NSMutableDictionary dictionaryWithCapacity:1];
        publicDictionary[@"id"] = [post.publicID numericValue];
        [metadata addObject:publicDictionary];
    }

    if (post.publicizeMessageID || post.publicizeMessage.length) {
        NSMutableDictionary *publicizeMessageDictionary = [NSMutableDictionary dictionaryWithCapacity:3];
        if (post.publicizeMessageID) {
            publicizeMessageDictionary[@"id"] = post.publicizeMessageID;
        }
        publicizeMessageDictionary[@"key"] = @"_wpas_mess";
        publicizeMessageDictionary[@"value"] = post.publicizeMessage.length ? post.publicizeMessage : @"";
        [metadata addObject:publicizeMessageDictionary];
    }

    for (NSNumber *keyringConnectionId in post.disabledPublicizeConnections.allKeys) {
        NSMutableDictionary *disabledConnectionsDictionary = [NSMutableDictionary dictionaryWithCapacity: 3];
        // We need to compose back the key
        disabledConnectionsDictionary[@"key"] = [NSString stringWithFormat:@"_wpas_skip_%@",
                                                                           keyringConnectionId];
        [disabledConnectionsDictionary addEntriesFromDictionary:post.disabledPublicizeConnections[keyringConnectionId]];
        [metadata addObject:disabledConnectionsDictionary];
    }

    if (post.bloggingPromptID) {
        NSMutableDictionary *promptDictionary = [NSMutableDictionary dictionaryWithCapacity:3];
        promptDictionary[@"key"] = @"_jetpack_blogging_prompt_key";
        promptDictionary[@"value"] = post.bloggingPromptID;
        [metadata addObject:promptDictionary];
    }

    return metadata;
}

+ (void)updatePost:(Post *)post withRemoteCategories:(NSArray *)remoteCategories inContext:(NSManagedObjectContext *)context {
    NSManagedObjectID *blogObjectID = post.blog.objectID;
    NSMutableSet *categories = [post mutableSetValueForKey:@"categories"];
    [categories removeAllObjects];
    for (RemotePostCategory *remoteCategory in remoteCategories) {
        PostCategory *category = [PostCategory lookupWithBlogObjectID:blogObjectID categoryID:remoteCategory.categoryID inContext:context];
        if (!category) {
            category = [PostCategory createWithBlogObjectID:blogObjectID inContext:context];
            category.categoryID = remoteCategory.categoryID;
            category.categoryName = remoteCategory.name;
            category.parentID = remoteCategory.parentID;
        }
        [categories addObject:category];
    }
}

+ (void)updateCommentsForPost:(AbstractPost *)post
{
    NSMutableSet *currentComments = [post mutableSetValueForKey:@"comments"];
    NSSet *allComments = [post.blog.comments filteredSetUsingPredicate:[NSPredicate predicateWithFormat:@"postID = %@", post.postID]];
    [currentComments unionSet:allComments];
}

+ (NSDictionary *)dictionaryWithKey:(NSString *)key inMetadata:(NSArray *)metadata {
    NSArray *matchingEntries = [metadata filteredArrayUsingPredicate:[NSPredicate predicateWithFormat:@"key = %@", key]];
    // In theory, there shouldn't be duplicated fields, but I've seen some bugs where there's more than one geo_* value
    // In any case, they should be sorted by id, so `lastObject` should have the newer value
    return [matchingEntries lastObject];
}

+ (NSArray *)entriesWithKeyLike:(NSString *)key inMetadata:(NSArray *)metadata
{
    return [metadata filteredArrayUsingPredicate:[NSPredicate predicateWithFormat:@"key like %@", key]];
}

@end
