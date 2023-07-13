import SwiftUI
import Foundation
import PDFKit
import CachedAsyncImage

struct ZoomableImage: UIViewRepresentable {

        // used to set the image that will be displayed in the PDFView
        private(set) var image: UIImage
        
        // sets the background color of the PDFView
        private(set) var backgroundColor: Color
        
        // sets the minimum scale factor for zooming out of the image
        private(set) var minScaleFactor: CGFloat
 
        // sets the ideal scale factor for the image when it is first displayed in the PDFView
        // the initial zoom level of the image when it is first displayed
        private(set) var idealScaleFactor: CGFloat
        
        // sets the maximum scale factor for zooming in on the image
        private(set) var maxScaleFactor: CGFloat

        public init(
            image: UIImage,
            backgroundColor: Color,
            minScaleFactor: CGFloat,
            idealScaleFactor: CGFloat,
            maxScaleFactor: CGFloat
        ) {
            self.image = image
            self.backgroundColor = backgroundColor
            self.minScaleFactor = minScaleFactor
            self.idealScaleFactor = idealScaleFactor
            self.maxScaleFactor = maxScaleFactor
        }

        public func makeUIView(context: Context) -> PDFView {
            let view = PDFView()
            guard let page = PDFPage(image: image) else { return view }
            let document = PDFDocument()
            document.insert(page, at: 0)

            view.backgroundColor = UIColor(cgColor: backgroundColor.cgColor!)

            view.autoScales = true
            view.document = document

            view.maxScaleFactor = maxScaleFactor
            view.minScaleFactor = minScaleFactor
            view.scaleFactor = idealScaleFactor
            return view
        }

        public func updateUIView(_ uiView: PDFView, context: Context) {
            // empty
        }
 }


public struct ImageViewComponent<Content: View>: View {
    let url: URL
    let urlCache: URLCache
    @ViewBuilder var content: Content
    
    public init(url: URL, urlCache: URLCache = .shared, @ViewBuilder content: ()->Content) {
        self.url = url
        self.urlCache = urlCache
        self.content = content()
    }
    
    public var body: some View {
        CachedAsyncImage(url: url, urlCache: urlCache) { image in
            let renderer = ImageRenderer(content: image)
            if let uiImage = renderer.uiImage?.resized(toWidth: UIScreen.main.bounds.width) {
                VStack {
                    ZoomableImage(image: uiImage, backgroundColor: .black, minScaleFactor: 1, idealScaleFactor: 1, maxScaleFactor: 10)
                    content
                }
            }
        } placeholder: {
            ProgressView()
        }
    }
}

extension UIImage {
    func resized(withPercentage percentage: CGFloat, isOpaque: Bool = true) -> UIImage? {
        let canvas = CGSize(width: size.width * percentage, height: size.height * percentage)
        let format = imageRendererFormat
        format.opaque = isOpaque
        return UIGraphicsImageRenderer(size: canvas, format: format).image {
            _ in draw(in: CGRect(origin: .zero, size: canvas))
        }
    }

    func resized(toWidth width: CGFloat, isOpaque: Bool = true) -> UIImage? {
        let canvas = CGSize(width: width, height: CGFloat(ceil(width / size.width * size.height)))
        let format = imageRendererFormat
        format.opaque = isOpaque
        return UIGraphicsImageRenderer(size: canvas, format: format).image {
            _ in draw(in: CGRect(origin: .zero, size: canvas))
        }
    }
}
