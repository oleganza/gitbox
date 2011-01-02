#import "OAXMLDecoder.h"


@interface OAXMLDecoder()

@property(nonatomic, retain) NSMutableString* currentStringBuffer;
@property(nonatomic, retain) NSMutableArray* startMapStack;
@property(nonatomic, retain) NSMutableArray* endMapStack;
@property(nonatomic, retain) NSMutableDictionary* currentStartMap; // elementName -> block
@property(nonatomic, retain) NSMutableDictionary* currentEndMap; // elementName -> block

- (void) debugElementWithMessage:(NSString*)msg;

@end

@implementation OAXMLDecoder

@synthesize xmlData;
@synthesize xmlParser;
@synthesize currentString;
@synthesize currentAttributes;
@synthesize currentQualifiedName;
@synthesize currentNamespaceURI;
@synthesize currentElementName;
@synthesize error;
@synthesize startMapStack;
@synthesize endMapStack;
@synthesize currentStartMap;
@synthesize currentEndMap;
@synthesize currentStringBuffer;

@synthesize caseInsensitive;
@synthesize succeed;
@synthesize traceParsing;

- (void) dealloc
{
	self.xmlData = nil;
	self.xmlParser = nil;
	self.currentStringBuffer = nil;
	self.currentAttributes = nil;
	self.currentQualifiedName = nil;
	self.currentNamespaceURI = nil;
	self.currentElementName = nil;
	self.error = nil;
	self.startMapStack = nil;
	self.endMapStack = nil;
	self.currentStartMap = nil;
	self.currentEndMap = nil;

	[super dealloc];
}

- (void) decodeWithObject:(id<NSObject>)rootObject startSelector:(SEL)startSelector
{
	[self decodeWithObject:rootObject startSelector:startSelector endSelector:NULL];
}

- (void) decodeWithObject:(id<NSObject>)rootObject startSelector:(SEL)startSelector endSelector:(SEL)endSelector
{
	[self decodeWithObject:rootObject startSelector:startSelector endBlock:^{
		if (endSelector)
		{
			[rootObject performSelector:endSelector withObject:self];
		}
	}];
}

- (void) decodeWithObject:(id<NSObject>)rootObject startSelector:(SEL)startSelector endBlock:(void(^)())endBlock
{
	self.startMapStack = [NSMutableArray arrayWithCapacity:8];
	self.endMapStack = [NSMutableArray arrayWithCapacity:8];
	
	self.xmlParser = [[[NSXMLParser alloc] initWithData:self.xmlData] autorelease];
	[self.xmlParser setShouldProcessNamespaces:YES];
	[self.xmlParser setShouldReportNamespacePrefixes:YES];
	[self.xmlParser setDelegate:self];
	
	self.currentStartMap = [NSMutableDictionary dictionary];
	self.currentEndMap = [NSMutableDictionary dictionary];
	
	if (startSelector)
	{
		[rootObject performSelector:startSelector withObject:self];
	}
	
	self.succeed = [self.xmlParser parse];
	
	if (!self.succeed)
	{
		self.error = [self.xmlParser parserError];
		NSLog(@"OAXMLDecoder failed to parse XML list");
	}
	
	if (endBlock) endBlock();
	
	// Cleanup possible referential cycles within blocks
	self.startMapStack = nil;
	self.endMapStack = nil;
	self.currentStartMap = nil;
	self.currentEndMap = nil;
	self.xmlParser = nil;
}






#pragma mark Callbacks



- (void) parseElement:(NSString*)elementName startBlock:(void(^)())startBlock endBlock:(void(^)())endBlock
{
	startBlock = [[startBlock copy] autorelease];
	endBlock = [[endBlock copy] autorelease];
	[self startElement:elementName withBlock:startBlock];
	[self endElement:elementName withBlock:endBlock];
}

- (void) parseElements:(id<NSFastEnumeration>)elements startBlock:(void(^)())startBlock endBlock:(void(^)())endBlock
{
	startBlock = [[startBlock copy] autorelease];
	endBlock = [[endBlock copy] autorelease];
	[self startElements:elements withBlock:startBlock];
	[self endElements:elements withBlock:endBlock];
}



- (void) startElement:(NSString*)elementName withBlock:(void(^)())block
{
	if (!block) return;
	//NSLog(@"OAXMLDecoder: register block for start element: %@", elementName);
	if (self.caseInsensitive) elementName = [elementName lowercaseString];
	void(^existingBlock)() = [self.currentStartMap objectForKey:elementName];
	if (existingBlock)
	{
		block = [[block copy] autorelease];
		block = ^{
			existingBlock();
			block();
		};
	}
	[self.currentStartMap setObject:[[block copy] autorelease] forKey:elementName];
}

- (void) startOptionalElement:(NSString*)elementName withBlock:(void(^)())block
{
	[self startElement:elementName withBlock:block];
	block();
}

- (void) startElements:(id<NSFastEnumeration>)elements withBlock:(void(^)())block
{
	block = [[block copy] autorelease];
	for (NSString* element in elements)
	{
		[self startElement:element withBlock:block];
	}
}

- (void) startOptionalElements:(id<NSFastEnumeration>)elements withBlock:(void(^)())block
{
	[self startElements:elements withBlock:block];
	block();
}

- (void) endElement:(NSString*)elementName withBlock:(void(^)())block
{
	if (!block) return;
	//NSLog(@"OAXMLDecoder: register block for end element: %@", elementName);
	if (self.caseInsensitive) elementName = [elementName lowercaseString];
	void(^existingBlock)() = [self.currentEndMap objectForKey:elementName];
	if (existingBlock)
	{
		block = [[block copy] autorelease];
		block = ^{
			existingBlock();
			block();
		};
	}
	[self.currentEndMap setObject:[[block copy] autorelease] forKey:elementName];
}

- (void) endElements:(id<NSFastEnumeration>)elements withBlock:(void(^)())block
{
	block = [[block copy] autorelease];
	for (NSString* element in elements)
	{
		[self endElement:element withBlock:block];
	}
}





#pragma mark Accessors



- (NSString*) attributeForName:(NSString*)attrName
{
	return [self.currentAttributes objectForKey:attrName];
}

- (NSString*) currentString
{
	return [NSString stringWithString:self.currentStringBuffer];
}

- (NSString*) currentStringStripped
{
	return [self.currentString stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
}








#pragma mark NSXMLParserDelegate




- (void)       parser:(NSXMLParser*) parser 
      didStartElement:(NSString*) elementName
         namespaceURI:(NSString*) namespaceURI 
        qualifiedName:(NSString*) qualifiedName
           attributes:(NSDictionary*) attributesDict
{
	if (self.caseInsensitive) qualifiedName = [qualifiedName lowercaseString];
	
	//NSLog(@"OAXMLDecoder: start element %@", qualifiedName);
	
	if (self.traceParsing) [self debugElementWithMessage:[NSString stringWithFormat:@"<%@>", qualifiedName]];
	
	self.currentStringBuffer = [NSMutableString string];
	self.currentNamespaceURI = namespaceURI;
	self.currentQualifiedName = qualifiedName;
	self.currentAttributes = attributesDict;
	self.currentElementName = elementName;
	
	void(^startBlock)() = [self.currentStartMap objectForKey:qualifiedName];
	
	[self.startMapStack addObject:self.currentStartMap];
	[self.endMapStack addObject:self.currentEndMap];
	
	self.currentStartMap = [NSMutableDictionary dictionary];
	self.currentEndMap = [NSMutableDictionary dictionary];
	
	if (startBlock) startBlock(); // block fills in currentStartMap and currentEndMap
}



- (void)parser:(NSXMLParser*)parser foundCharacters:(NSString*)string 
{
	// TODO: provide a way for client to gather the whole content with a block here
	[self.currentStringBuffer appendString:string];
}



- (void)     parser:(NSXMLParser*) parser 
      didEndElement:(NSString*) elementName
       namespaceURI:(NSString*) namespaceURI
      qualifiedName:(NSString*) qualifiedName
{
	//NSLog(@"OAXMLDecoder: end element %@", qualifiedName);
	
	if (self.caseInsensitive) qualifiedName = [qualifiedName lowercaseString];
	
	NSMutableDictionary* startMap = [self.startMapStack lastObject];
	NSMutableDictionary* endMap = [self.endMapStack lastObject];
	
	// We do not keep a stack of the attributes, so they will be overwritten by nested tags.
	// Here we explicitly reject it to make sure client does not try to use it.
	// TODO: keep a stack of the attributes so we don't have this issue
	self.currentAttributes = nil;
	
	self.currentNamespaceURI = namespaceURI;
	self.currentQualifiedName = qualifiedName;
	self.currentElementName = elementName;
	
	void(^endBlock)() = [endMap objectForKey:qualifiedName];
	if (endBlock) endBlock();
	
	self.currentStartMap = startMap;
	self.currentEndMap = endMap;
	
	[self.startMapStack removeLastObject];
	[self.endMapStack removeLastObject];
	
	if (self.traceParsing) [self debugElementWithMessage:[NSString stringWithFormat:@"</%@>", qualifiedName]];
	
	self.currentStringBuffer = [NSMutableString string];
}








- (void) debugElementWithMessage:(NSString*)msg
{
	NSUInteger offset = [self.startMapStack count];
	NSMutableString* indentation = [NSMutableString string];
	
	while (offset--)
	{
		[indentation appendString:@"    "];
	}
	
	NSLog(@"%@: %@%@", [self class], indentation, msg);
}


@end
