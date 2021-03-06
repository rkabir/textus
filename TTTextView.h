//
//  JJTextView.h
//  Textus
//
//  Created by Jjgod Jiang on 3/16/09.
//  Copyright 2009 Jjgod Jiang. All rights reserved.
//

#import <Cocoa/Cocoa.h>
#import <vector>

using namespace std;

typedef struct LineData {
    CTLineRef line;
    CGPoint   origin;
} JJLineData;

@class TTDocument;

@interface TTTextView : NSView {
    NSSize textInset;
    vector<JJLineData> textLines;
    TTDocument *document;
}

@property (assign) NSSize textInset;
@property (assign) TTDocument *document;

- (void) invalidateLayout;
- (void) scrollToLine: (NSUInteger) line;
- (void) doPartialLayoutWithMaximumHeight: (CGFloat) height aroundLine: (NSUInteger) line;

@end
