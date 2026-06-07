#import <Foundation/Foundation.h>
#import <CoreGraphics/CoreGraphics.h>

NS_ASSUME_NONNULL_BEGIN

// ── MuPDFTextChar ────────────────────────────────────────────────────────────
/// A single character with its bounding quad in PDF page coordinates.
@interface MuPDFTextChar : NSObject
@property (nonatomic) unichar character;
@property (nonatomic) CGRect  bounds;      // PDF coords (y-up, bottom-left origin)
@property (nonatomic) float   fontSize;
@end

// ── MuPDFTextLine ────────────────────────────────────────────────────────────
@interface MuPDFTextLine : NSObject
@property (nonatomic, copy) NSArray<MuPDFTextChar *> *chars;
@property (nonatomic, copy) NSString *text;
@property (nonatomic) CGRect bounds;
@end

// ── MuPDFTextBlock ───────────────────────────────────────────────────────────
/// A block of text (paragraph) on a PDF page.
@interface MuPDFTextBlock : NSObject
@property (nonatomic, copy) NSArray<MuPDFTextLine *> *lines;
@property (nonatomic, copy) NSString *text;     // full text of the block
@property (nonatomic) CGRect  bounds;           // PDF coords
@property (nonatomic) int     pageIndex;
@property (nonatomic) float   dominantFontSize; // most common font size in block
@end

// ── PDFMuPDFBridge ───────────────────────────────────────────────────────────
/// Thin Obj-C++ wrapper around MuPDF's C API.
/// Thread-safety: all methods must be called from the same thread.
@interface PDFMuPDFBridge : NSObject

/// Opens a PDF at the given URL. Returns nil on failure.
- (nullable instancetype)initWithURL:(NSURL *)url error:(NSError *_Nullable *_Nullable)error;

/// Page count of the loaded document.
@property (nonatomic, readonly) int pageCount;

/// Returns all text blocks on the given page, in PDF coordinate space.
- (NSArray<MuPDFTextBlock *> *)textBlocksOnPage:(int)pageIndex;

/// Redacts the given rect on a page (removes the underlying content stream text).
/// Call -saveToURL:error: afterward to persist the change.
- (BOOL)redactRect:(CGRect)rect
            onPage:(int)pageIndex
             error:(NSError *_Nullable *_Nullable)error;

/// Saves the (possibly edited) document to a URL.
- (BOOL)saveToURL:(NSURL *)url error:(NSError *_Nullable *_Nullable)error;

@end

NS_ASSUME_NONNULL_END
