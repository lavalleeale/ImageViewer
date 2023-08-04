import CachedAsyncImage
import Foundation
import PDFKit
import SwiftUI

struct ZoomableImage: UIViewRepresentable {
    // used to set the image that will be displayed in the PDFView
    private(set) var image: UIImage

    // sets the minimum scale factor for zooming out of the image
    private(set) var minScaleFactor: CGFloat

    // sets the ideal scale factor for the image when it is first displayed in the PDFView
    // the initial zoom level of the image when it is first displayed
    private(set) var idealScaleFactor: CGFloat

    // sets the maximum scale factor for zooming in on the image
    private(set) var maxScaleFactor: CGFloat

    public init(
        image: UIImage,
        minScaleFactor: CGFloat,
        idealScaleFactor: CGFloat,
        maxScaleFactor: CGFloat
    ) {
        self.image = image
        self.minScaleFactor = minScaleFactor
        self.idealScaleFactor = idealScaleFactor
        self.maxScaleFactor = maxScaleFactor
    }

    public func makeUIView(context: Context) -> PDFView {
        let view = PDFView()
        guard let page = PDFPage(image: image) else { return view }
        let document = PDFDocument()
        document.insert(page, at: 0)

        view.backgroundColor = .clear

        view.autoScales = true
        view.document = document
        let pdfScrollView = view.findUIScrollView()
        pdfScrollView?.showsHorizontalScrollIndicator = false // if pdf view scroll direction is horizontal
        pdfScrollView?.showsVerticalScrollIndicator = false // if pdf view scroll direction is vertical
        pdfScrollView?.isDirectionalLockEnabled = false

        view.maxScaleFactor = maxScaleFactor
        view.minScaleFactor = minScaleFactor
        view.scaleFactor = idealScaleFactor
        return view
    }

    public func updateUIView(_ uiView: PDFView, context: Context) {
        // empty
    }
}

struct TransparentBackground: UIViewRepresentable {
    func makeUIView(context: Context) -> UIView {
        let view = UIView()
        DispatchQueue.main.async {
            view.superview?.superview?.backgroundColor = .clear
        }
        return view
    }

    func updateUIView(_ uiView: UIView, context: Context) {}
}

public struct ImageViewComponent<Content: View>: View {
    let url: URL
    let urlCache: URLCache
    @ViewBuilder var content: Content
    @State var offset: CGSize = .zero
    @Binding var showing: Bool
    
    public init(url: URL, urlCache: URLCache = .shared, showing: Binding<Bool>, @ViewBuilder content: () -> Content) {
        self.url = url
        self.urlCache = urlCache
        self._showing = showing
        self.content = content()
    }
    
    public var body: some View {
        Rectangle().frame(width: 0, height: 0).clipped().fullScreenCover(isPresented: $showing) {
        ZStack {
            let opactity = (300 - offset.magnitude) / 300
            Color.black.opacity(opactity)
            CachedAsyncImage(url: url, urlCache: urlCache) { image in
                let renderer = ImageRenderer(content: image)
                if let uiImage = renderer.uiImage {
                    let scaleFactor = UIScreen.main.bounds.width / uiImage.size.width
                    ZoomableImage(image: uiImage, minScaleFactor: scaleFactor, idealScaleFactor: scaleFactor, maxScaleFactor: 5 * scaleFactor)
                        .offset(offset)
                        .onTapGesture {}
                        .gesture(DragGesture().onChanged { gesture in
                            offset = CGSize(width: gesture.location.x - gesture.startLocation.x, height: gesture.location.y - gesture.startLocation.y)
                        }.onEnded { gesture in
                            offset = CGSize(width: gesture.predictedEndLocation.x - gesture.startLocation.x, height: gesture.location.y - gesture.predictedEndLocation.y)
                            if offset.magnitude > 200 {
                                self.showing = false
                            }
                            withAnimation {
                                offset = .zero
                            }
                        })
                        .overlay(alignment: .bottom) {
                            content
                                .foregroundStyle(.white)
                        }
                        .opacity(opactity)
                }
            } placeholder: {
                ProgressView()
            }
        }
        .ignoresSafeArea()
        .overlay(alignment: .topLeading) {
            Label {
                Text("Close")
            } icon: {
                Image(systemName: "xmark")
                    .resizable()
                    .frame(width: 24, height: 24)
            }
            .statusBar(hidden: true)
            .padding([.top, .leading], 24)
            .padding([.bottom, .trailing], 48)
            .ignoresSafeArea()
            .labelStyle(.iconOnly)
            .contentShape(Rectangle())
            .onTapGesture {
                self.showing = false
            }
            .foregroundStyle(.white)
        }
        .background(TransparentBackground())
    }
}
}

extension PDFView {
    var scrollView: UIScrollView? {
        guard let pageViewControllerContentView = subviews.first else { return nil }
        for view in pageViewControllerContentView.subviews {
            guard let scrollView = view as? UIScrollView else { continue }
            return scrollView
        }

        return nil
    }
}

extension UIView {
    func findUIScrollView() -> UIScrollView? {
        if let scrollView = self as? UIScrollView {
            return scrollView
        }

        for view in subviews {
            if let scrollView = view as? UIScrollView {
                return scrollView
            }

            if !view.subviews.isEmpty {
                return view.findUIScrollView()
            }
        }
        return nil
    }
}

extension CGSize {
    var magnitude: Double {
        return sqrt(pow(width, 2) + pow(height, 2))
    }
}
