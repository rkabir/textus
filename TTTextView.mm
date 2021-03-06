//
//  JJTextView.m
//  Textus
//
//  Created by Jjgod Jiang on 3/16/09.
//  Copyright 2009 Jjgod Jiang. All rights reserved.
//

#import "TTTextView.h"
#import "TTDocument.h"
#import <time.h>

#define kMaxLinesPerFrame 256

#define MAX_LINES(total)    (total > kMaxLinesPerFrame ? kMaxLinesPerFrame : total)

@implementation TTTextView

@synthesize textInset;
@synthesize document;

- (id) initWithFrame: (NSRect) frameRect
{
    if ((self = [super initWithFrame: frameRect]))
    {
        textInset = NSMakeSize(50, 50);
        textLines.clear();
    }
    return self;
}

- (void) removeAllLines
{
    NSUInteger i, count = textLines.size();

    NSLog(@"total lines: %u", count);

    for (i = 0; i < count; i++)
        CFRelease(textLines[i].line);

    textLines.clear();
}

- (void) dealloc
{
    [self removeAllLines];
    [super dealloc];
}

- (void) invalidateLayout
{
    NSAttributedString *text = [document fileContents];
    clock_t startTime = clock(), duration;

    if (! text)
        return;

    NSSize contentSize = [[self enclosingScrollView] contentSize];
    NSLog(@"Original content size: %@", NSStringFromSize(contentSize));
    CTFontRef font = (CTFontRef) [text attribute: (NSString *) kCTFontAttributeName
                                         atIndex: 0
                                  effectiveRange: NULL];
    CGFloat lineHeight = CTFontGetAscent(font) + CTFontGetDescent(font) + CTFontGetLeading(font);
    CGFloat lineAscent = CTFontGetAscent(font);
    lineHeight *= [[NSUserDefaults standardUserDefaults] doubleForKey: @"lineHeight"];

    // Create the framesetter with the attributed string.
    CTFramesetterRef framesetter = CTFramesetterCreateWithAttributedString((CFAttributedStringRef) text);

    CFRange fullRange = CFRangeMake(0, text.length);
    CGRect frameRect = CGRectMake(textInset.width, textInset.height,
                                  contentSize.width - 2 * textInset.width - [NSScroller scrollerWidth],
                                  contentSize.height - textInset.height);

    CFRange range, frameRange;
    JJLineData lineData = { NULL, CGPointMake(0, 0) };

    [self removeAllLines];
    for (range = frameRange = CFRangeMake(0, 0);
         range.location < fullRange.length;
         range.location += frameRange.length)
    {
        CGMutablePathRef path = CGPathCreateMutable();
        CGPathAddRect(path, NULL, frameRect);

        CTFrameRef frame = CTFramesetterCreateFrame(framesetter, range, path, NULL);
        frameRange = CTFrameGetVisibleStringRange(frame);
        CFArrayRef lines = CTFrameGetLines(frame);
        CFIndex i, total = CFArrayGetCount(lines);
        CGFloat y = frameRect.origin.y;
        for (i = 0; i < total; i++)
        {
            lineData.line = (CTLineRef) CFRetain(CFArrayGetValueAtIndex(lines, i));
            // NSLog(@"y = %g\n", y);
            lineData.origin = CGPointMake(frameRect.origin.x, y + lineAscent);
            y += lineHeight;
            textLines.push_back(lineData);
        }
#if 0
        NSLog(@"frameRange: %ld, %ld, %@",
              frameRange.location, frameRange.length,
              NSStringFromRect(NSRectFromCGRect(frameRect)));
#endif
        frameRect.origin.y = y;
        frameRect.size.height = contentSize.height;
        CFRelease(path);
        CFRelease(frame);
    }

    CFRelease(framesetter);

    duration = clock() - startTime;
    NSLog(@"layout time = %g secs", (double) duration / (double) CLOCKS_PER_SEC);

    NSRect newFrame = [self frame];
    newFrame.size.height = frameRect.origin.y + textInset.height;

    [self setFrame: newFrame];
    [self setNeedsDisplay: YES];
}

- (void) doPartialLayoutWithMaximumHeight: (CGFloat) height aroundLine: (NSUInteger) line
{
    NSString *plainText = [document fileContentsInPlainText];
    NSAttributedString *text = [document fileContents];
    clock_t startTime = clock(), duration;

    if (! text)
        return;

    NSSize contentSize = [[self enclosingScrollView] contentSize];
    NSDictionary *attributes = [document attributesForText];
    CTFontRef font = (CTFontRef) [attributes objectForKey: (NSString *) kCTFontAttributeName];
    CGFloat lineHeight = CTFontGetAscent(font) + CTFontGetDescent(font) + CTFontGetLeading(font);
    CGFloat lineAscent = CTFontGetAscent(font);
    lineHeight *= [[NSUserDefaults standardUserDefaults] doubleForKey: @"lineHeight"];

    NSRange partRange = NSMakeRange(0, 2048);
    NSRange lineRange = [plainText lineRangeForRange: partRange];
    
    NSLog(@"lineRange: %@", NSStringFromRange(lineRange));
    
    // Create the framesetter with the attributed string.
    CTFramesetterRef framesetter = CTFramesetterCreateWithAttributedString((CFAttributedStringRef)
                                                                           [text attributedSubstringFromRange: lineRange]);

    CGRect frameRect = CGRectMake(textInset.width, textInset.height,
                                  contentSize.width - 2 * textInset.width - [NSScroller scrollerWidth],
                                  contentSize.height);
    
    CFRange range, frameRange;
    JJLineData lineData = { NULL, CGPointMake(0, 0) };
    
    [self removeAllLines];

    range = frameRange = CFRangeMake(0, 0);
    CGMutablePathRef path = CGPathCreateMutable();
    CGPathAddRect(path, NULL, frameRect);

    CTFrameRef frame = CTFramesetterCreateFrame(framesetter, range, path, NULL);
    frameRange = CTFrameGetVisibleStringRange(frame);
    CFArrayRef lines = CTFrameGetLines(frame);
    CFIndex i, total = CFArrayGetCount(lines);
    CGFloat y = frameRect.origin.y;
    for (i = 0; i < total; i++)
    {
        lineData.line = (CTLineRef) CFRetain(CFArrayGetValueAtIndex(lines, i));
        lineData.origin = CGPointMake(frameRect.origin.x, y + lineAscent);
        y += lineHeight;
        textLines.push_back(lineData);
    }

    CFRelease(path);
    CFRelease(frame);
    CFRelease(framesetter);
    
    duration = clock() - startTime;
    NSLog(@"layout time = %g secs", (double) duration / (double) CLOCKS_PER_SEC);
    
    NSRect newFrame = [self frame];
    newFrame.size.height = height;
    
    [self setFrame: newFrame];
    [self setNeedsDisplay: YES];
}

- (BOOL) isFlipped
{
    return YES;
}

// Do a binary search to find the line requested
- (NSUInteger) lineBefore: (CGFloat) y
{
    NSUInteger i;

    for (i = 0; i < textLines.size(); i++)
        if (textLines[i].origin.y > y)
            return i == 0 ? 0 : i - 1;

    return i;
}

- (void) drawRect: (NSRect) rect
{
    // Initialize a graphics context and set the text matrix to a known value.
    CGContextRef context = (CGContextRef)[[NSGraphicsContext currentContext] graphicsPort];
    CGContextSetTextMatrix(context, CGAffineTransformMakeScale(1, -1));

    // NSLog(@"drawRect: %@", NSStringFromRect(rect));

    NSUInteger i, from, total = textLines.size();
    JJLineData lineData = { NULL, CGPointZero };
    CGFloat bottom = rect.origin.y + rect.size.height;

    from = [self lineBefore: rect.origin.y];
    for (i = from; i < total && lineData.origin.y <= bottom; i++)
    {
        lineData = textLines[i];

        // NSRectFill(NSMakeRect(lineData.origin.x, lineData.origin.y, 20, 1.5));
        CGContextSetTextPosition(context, lineData.origin.x, lineData.origin.y);
        CTLineDraw(lineData.line, context);
    }

    [document setLastReadLine: [self lineBefore: [[self enclosingScrollView] documentVisibleRect].origin.y]];
    // NSLog(@"drawLines from: %u to %u", from, i);
}

- (void) scrollTo: (float) y
{
    [self scrollPoint: NSMakePoint(0.0, y)];
}

- (void) scrollBy: (float) value
{
    CGFloat y;
    NSRect rect;

    rect = [[self enclosingScrollView] documentVisibleRect];
    y = rect.origin.y;
    y += value;

    [self scrollTo: y];
}

- (BOOL) processKey: (int) ch
{
    float y;
    CGFloat pageHeight = [(NSScrollView *) [self superview] documentVisibleRect].size.height;

    switch (ch)
    {
        case NSDownArrowFunctionKey:
            [self scrollBy: 100.0];
            break;
            
        case NSUpArrowFunctionKey:
            [self scrollBy: -100.0];
            break;
            
        case ' ':
        case NSPageDownFunctionKey:
            [self scrollBy: pageHeight];
            break;
            
        case NSPageUpFunctionKey:
            [self scrollBy: -pageHeight];
            break;
            
        case NSEndFunctionKey:
            y = NSMaxY([[[self enclosingScrollView] documentView] frame]) - 
            NSHeight([[[self enclosingScrollView] contentView] bounds]);
            [self scrollTo: y];
            break;

        case NSHomeFunctionKey:
            [self scrollTo: 0];
            break;

        default:
            return NO;
    }

    return YES;
}

- (void) keyDown: (NSEvent *) event 
{
    int characterIndex;
    int charactersInEvent;

    charactersInEvent = [[event characters] length];
    for (characterIndex = 0; characterIndex < charactersInEvent;  
         characterIndex++) {
        int ch = [[event characters] characterAtIndex:characterIndex];
        
        if ([self processKey: ch] == NO)
            [self interpretKeyEvents:[NSArray arrayWithObject:event]];
    }
}

- (BOOL) acceptsFirstResponder
{
    return YES;
}

- (void) viewDidEndLiveResize
{
    [self invalidateLayout];
}

- (void) scrollToLine: (NSUInteger) line
{
    if (line > 0 && line < textLines.size())
        [self scrollTo: textLines[line].origin.y];
}

@end
