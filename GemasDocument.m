/* 
   Copyright (C) 2010, 2011, 2012, 2013 German A. Arias <german@xelalug.org>
   Copyright (C) 2020 Anthony Cohn-Richardby <anthonyc@gmx.co.uk>

   This file is part of Gemas application

   Gemas is free software; you can redistribute it and/or
   modify it under the terms of the GNU General Public
   License as published by the Free Software Foundation; either
   version 3 of the License, or (at your option) any later version.
 
   This application is distributed in the hope that it will be useful,
   but WITHOUT ANY WARRANTY; without even the implied warranty of
   MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
   Library General Public License for more details.
 
   You should have received a copy of the GNU General Public
   License along with this library; if not, write to the Free
   Software Foundation, Inc., 59 Temple Place, Suite 330, Boston, MA 02111 USA.
*/

#import "GemasController.h"
#import "GemasDocument.h"
#import "GemasEditorView.h"
#import "GNUstepGUI/GSTheme.h"
#import "Preferences.h"
#import "InputModifiers/ObjcAutoIndenter.h"
#import <Foundation/NSUserDefaults.h>
#import <HighlighterKit/HighlighterKit.h>

@interface GemasDocument (Private)

- (void) setupNewDefaults;

@end

@implementation GemasDocument (Private)

- (void) setupNewDefaults
{
  NSFont *font = nil;
  NSUserDefaults * df = [NSUserDefaults standardUserDefaults];
  NSData * data;

  data = [df dataForKey: @"EditorTextColor"];
  if (data != nil)
    {
      ASSIGN (textColor, [NSKeyedUnarchiver unarchiveObjectWithData: data]);
    }
  else
    {
      ASSIGN (textColor, [NSColor blackColor]);
    }
  
  [textView setTextColor: textColor];

  data = [df dataForKey: @"EditorBackgroundColor"];
  if (data != nil)
    {
      [textView setBackgroundColor: [NSKeyedUnarchiver unarchiveObjectWithData: data]];
    }
  else
    {
      [textView setBackgroundColor: [NSColor whiteColor]];
    }

 data = [df dataForKey: @"EditorInsertionPointColor"];
  if (data != nil)
    {
      [textView setInsertionPointColor: [NSKeyedUnarchiver unarchiveObjectWithData: data]];
    }
  else
    {
      [textView setInsertionPointColor: [NSColor blackColor]];
    }
  
  data = [df dataForKey: @"EditorSelectionColor"];
  if (data != nil)
    {
      [textView setSelectedTextAttributes:
        [NSDictionary dictionaryWithObjectsAndKeys:
        [NSKeyedUnarchiver unarchiveObjectWithData: data], NSBackgroundColorAttributeName,
        [NSColor whiteColor], NSForegroundColorAttributeName,
        nil]];
    }
  else
    {
      [textView setSelectedTextAttributes:
        [NSDictionary dictionaryWithObjectsAndKeys:
        [NSColor grayColor], NSBackgroundColorAttributeName,
        [NSColor whiteColor], NSForegroundColorAttributeName,
        nil]];
    }
  
  /* Set the font here, so the textview knows beforehand the font size that
   * the highlighter will use. With this there isn't discrepancy about the
   * document size. */
  font = [HKSyntaxHighlighter defaultFont];
  if (font != nil)
    {
     [textView setFont: font];
    }

  //Set the syntax highlighter again
  [textView createSyntaxHighlighterForFileType: [self fileType]];
  
  NSMutableParagraphStyle *paragraphStyle = [[textView defaultParagraphStyle] mutableCopy];
  if (paragraphStyle == nil) 
  	 {
     paragraphStyle = [[NSMutableParagraphStyle alloc] init]; 
    }
  AUTORELEASE(paragraphStyle);
  int nspaces = [Preferences tabWidthSpaces];
  float charWidth = [[[textView font]
                          screenFontWithRenderingMode:NSFontDefaultRenderingMode]
                          advancementForGlyph:(NSGlyph) ' '].width;
  [paragraphStyle setDefaultTabInterval: nspaces * charWidth];
  // Workaround for versions of gnustep-gui without default tab fix
  NSMutableArray *tabstops = [NSMutableArray array];
  NSTextTab *tab;
  for (int i = 0; i < 10; i++) 
  	 {
     tab = [[NSTextTab alloc] initWithTextAlignment: NSTextAlignmentLeft
       location: i * charWidth * nspaces options: nil];
     AUTORELEASE(tab);
     [tabstops addObject: tab];
    }
  [paragraphStyle setTabStops: tabstops];
  [textView setDefaultParagraphStyle: paragraphStyle];
  
  NSMutableDictionary* typingAttributes = [[textView typingAttributes] mutableCopy];
  [typingAttributes setObject:paragraphStyle forKey:NSParagraphStyleAttributeName];
  [typingAttributes setObject:[textView font] forKey:NSFontAttributeName];
  [textView setTypingAttributes:typingAttributes];
  [[textView textStorage] addAttributes: typingAttributes 
    range: NSMakeRange(0, [[textView string] length])];

  [textView setNeedsDisplay: YES];
	
	 // Update the files autoindenter
	 if ([Preferences autoIndentEnabled]) 
	   {
	 	  [textView setAutoIndenter: AUTORELEASE([[ObjcAutoIndenter alloc] 
	 	    initWithFiletype: [self fileType]])];
 	   }
  else
  	 {
     [textView setAutoIndenter: nil];
    }
 
  [textView highlightRange: NSMakeRange(0, [[textView string] length])];
}

@end

@implementation GemasDocument

- (void) dealloc
{
  TEST_RELEASE (string);
  TEST_RELEASE (textColor);

  [[NSNotificationCenter defaultCenter] removeObserver: self];

  [super dealloc];
}

- (id)init
{
  if ((self = [super init]) != nil)
    {
      [[NSNotificationCenter defaultCenter]
        addObserver: self
           selector: @selector (defaultsChanged:)
               name: CodeEditorDefaultsDidChangeNotification
             object: nil];
      ASSIGN (string,@"");

      return self;
    }
  else
    {
      return nil;
    }
}

- (NSRect) getFrame
{
	NSArray *windowController = [self windowControllers];
	NSWindowController *controller = [windowController objectAtIndex: 0];
	NSWindow *window = [controller window];
	return [window frame];
}

- (void) setWindowFrame: (NSRect) frame
{

	NSArray *windowController = [self windowControllers];
	NSWindowController *controller = [windowController objectAtIndex: 0];
	NSWindow *window = [controller window];
	[window setFrame: frame display: YES];
}

- (BOOL) readFromFile: (NSString *) fileName ofType: (NSString *) fileType
{
  NSLog(@"read from file..");
  NSString *aString = [NSString stringWithContentsOfFile: fileName];

  if (aString != nil)
    { 
      ASSIGN (string, aString);

      return YES;
    }
  else
    {
      NSRunAlertPanel(_(@"Error"), _(@"Can't load the file."), _(@"OK"), nil, nil);
      return NO;
    }
}

- (BOOL) writeToFile: (NSString *) fileName ofType: (NSString *) fileType
{
  BOOL result;
  NSString *aString;
  
  [textView breakUndoCoalescing];
  aString = [textView string];
  result = [aString writeToFile: fileName atomically: NO];

  return result;
}

- (void) awakeFromNib
{
  NSMutableDictionary *typingAttrs;
  
  /* turn off ligatures */
  typingAttrs = [[[textView typingAttributes] mutableCopy] autorelease];
  [typingAttrs setObject: [NSNumber numberWithInt: 0]
               forKey: NSLigatureAttributeName];
  [textView setTypingAttributes: typingAttrs];
  [textView setAllowsUndo: YES];
  [textView setUsesFindPanel: YES];
  [textView setDrawsBackground: YES];
  
  [textView replaceCharactersInRange: NSMakeRange(0, 0) withString: string];
  [textView setSelectedRange: NSMakeRange(0, 0)];
  DESTROY(string);
  
  //Setup the user preferences
  [self setupNewDefaults];

  // Autocomplete
  length = 0;
}

- (NSString *) windowNibName
{
  return @"Editor";
}

- (void) goToLineNumber: (int)number
{
  NSUInteger offset = 0;
  NSUInteger i;
  NSUInteger lineNumber;
  NSRange rLine;
  NSString *line;
  NSArray *lines = [[textView string] componentsSeparatedByCharactersInSet:
                      [NSCharacterSet newlineCharacterSet]];
  NSEnumerator *search = [lines objectEnumerator];


  if (number < 0)
    {
      lineNumber = -1*number;
    }
  else
    {
      lineNumber = number;
    }

  for (i=1; (line = [search nextObject]) != nil && i < lineNumber; i++)
    {
      offset += [line length] + 1;
    }
  
  if (line != nil)
    {
      rLine = NSMakeRange(offset, [line length]);
    }
  else
    {
      rLine = NSMakeRange([[textView string] length], 0);
    }

  [textView setSelectedRange: rLine];
  [textView scrollRangeToVisible: rLine];
}

- (void) textViewDidChangeSelection: (NSNotification *) notification
{
  //Number of line and column
  NSRange tex = [textView selectedRange];
  NSArray *selectedLines = [[[textView string] substringWithRange: NSMakeRange(0, tex.location)] componentsSeparatedByString: @"\n"];

  [numberLine setIntValue: [selectedLines count]];
  [numberColumn setIntValue: [[selectedLines lastObject] length] + 1];
}

- (BOOL) revertToContentsOfURL: (NSURL*)url ofType: (NSString*)type error: (NSError**)error
{
  NSString *aString = [NSString stringWithContentsOfURL: url];
  NSMutableDictionary *typingAttrs;
  
  if (aString == nil)
   {
     return NO;
   }
  
  /* turn off ligatures */
  typingAttrs = [[[textView typingAttributes] mutableCopy] autorelease];
  [typingAttrs setObject: [NSNumber numberWithInt: 0]
               forKey: NSLigatureAttributeName];
  [textView setTypingAttributes: typingAttrs];
  [textView setAllowsUndo: YES];
  [textView setUsesFindPanel: YES];
  
  [textView replaceCharactersInRange: NSMakeRange(0, [[textView string] length])
            withString: aString];
  [textView setSelectedRange: NSMakeRange(0, 0)];
  
  //Setup the user preferences
  [self setupNewDefaults];
  
  //Set the syntax highlighter
  [textView createSyntaxHighlighterForFileType: [self fileType]];
  NSLog(@"Strlen: %lu", [string length]);
  [textView highlightRange: NSMakeRange(0, [string length])];
  return YES;
}

- (NSColor *) textColor
{
  return textColor;
}

- (void) defaultsChanged: (NSNotification *) notif
{
  [self setupNewDefaults];
}

- (void) windowDidBecomeMain: (NSNotification*)aNotification
{
}

- (void) windowWillClose: (NSNotification*)aNotification
{
}

- (NSArray *) textView: (NSTextView *)aTextView completions: (NSArray *)words
  forPartialWordRange: (NSRange)range indexOfSelectedItem: (NSInteger *)index
{
  NSString *word = [[aTextView string] substringWithRange: range];
  NSString *item;
  NSEnumerator *enumerator;
  NSMutableArray *array;
  
  if ([word length] < 3)
    {
      return nil;
    }
  
  if ( (words != nil) && (range.length > length) )
    {
      length = range.length;
      enumerator = [words objectEnumerator];
      array = [NSMutableArray array];
      
      while ((item = [enumerator nextObject]))
        {
          if ([item hasPrefix: word])
            {
              [array addObject: item];
            }
        }
    }
  else
    {
      length = range.length;
      enumerator = [[(GemasController *)[NSApp delegate] list] objectEnumerator];
      array = [NSMutableArray array];
      
      while ((item = [enumerator nextObject]))
        {
          if ([item hasPrefix: word])
            {
              [array addObject: item];
            }
        }
    }
  
  if ([array count] > 0)
    {
      return [NSArray arrayWithArray: array];
    }
  else
    {
      return nil;
    }
}

@end
