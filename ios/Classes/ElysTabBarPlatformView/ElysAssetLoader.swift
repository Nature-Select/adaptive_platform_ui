import Flutter
import UIKit

@available(iOS 26.0, *)
final class ElysAssetLoader {
    private weak var registrar: FlutterPluginRegistrar?
    // Bundle 资源在一次安装内不可变，可以按「路径+目标尺寸」缓存处理后的图；
    // file:// 、绝对路径、~/ 指向的文件可能在运行期被覆写，不能进缓存。
    private static let processedImageCache = NSCache<NSString, UIImage>()

    init(registrar: FlutterPluginRegistrar) {
        self.registrar = registrar
    }

    func image(named rawPath: String, size: CGSize, template: Bool = false) -> UIImage? {
        processedImage(
            rawPath: rawPath,
            cacheKeySuffix: "sized|\(size.width)x\(size.height)|\(template)"
        ) { image in
            let mode: UIImage.RenderingMode = template ? .alwaysTemplate : .alwaysOriginal
            return resize(image, to: size).withRenderingMode(mode)
        }
    }

    func imageAspectFit(named rawPath: String, maxSize: CGSize) -> UIImage? {
        processedImage(
            rawPath: rawPath,
            scale: UIScreen.main.scale,
            cacheKeySuffix: "fit|\(maxSize.width)x\(maxSize.height)"
        ) { image in
            aspectFit(image, maxSize: maxSize).withRenderingMode(.alwaysOriginal)
        }
    }

    private func processedImage(
        rawPath: String,
        scale: CGFloat = 1,
        cacheKeySuffix: String,
        process: (UIImage) -> UIImage
    ) -> UIImage? {
        let trimmed = rawPath.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }
        let cacheable = !Self.isMutableLocalReference(trimmed)
        let key = "\(trimmed)|\(cacheKeySuffix)|s\(scale)" as NSString
        if cacheable, let cached = Self.processedImageCache.object(forKey: key) {
            return cached
        }
        guard let image = loadImage(trimmed, scale: scale) else { return nil }
        let processed = process(image)
        if cacheable {
            Self.processedImageCache.setObject(processed, forKey: key)
        }
        return processed
    }

    static func isMutableLocalReference(_ path: String) -> Bool {
        path.hasPrefix("file://") || path.hasPrefix("/") || path.hasPrefix("~/")
    }

    private func loadImage(_ rawPath: String, scale: CGFloat = 1) -> UIImage? {
        let trimmed = rawPath.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }
        if let localPath = localFilePath(trimmed) {
            return loadImageFile(localPath, scale: scale)
        }
        if let key = registrar?.lookupKey(forAsset: trimmed),
           let path = Bundle.main.path(forResource: key, ofType: nil) {
            return loadImageFile(path, scale: scale)
        }
        let direct = Bundle.main.bundleURL
            .appendingPathComponent("Frameworks/App.framework/flutter_assets")
            .appendingPathComponent(trimmed)
            .path
        if FileManager.default.fileExists(atPath: direct) {
            return loadImageFile(direct, scale: scale)
        }
        return nil
    }

    private func loadImageFile(_ path: String, scale: CGFloat) -> UIImage? {
        if scale <= 1 { return UIImage(contentsOfFile: path) }
        guard let data = try? Data(contentsOf: URL(fileURLWithPath: path)) else { return nil }
        return UIImage(data: data, scale: scale)
    }

    private func localFilePath(_ rawPath: String) -> String? {
        if rawPath.hasPrefix("file://"), let url = URL(string: rawPath),
           FileManager.default.fileExists(atPath: url.path) { return url.path }
        if rawPath.hasPrefix("/"), FileManager.default.fileExists(atPath: rawPath) {
            return rawPath
        }
        if rawPath.hasPrefix("~/") {
            let expanded = NSString(string: rawPath).expandingTildeInPath
            if FileManager.default.fileExists(atPath: expanded) { return expanded }
        }
        return nil
    }

    private func resize(_ image: UIImage, to size: CGSize) -> UIImage {
        UIGraphicsBeginImageContextWithOptions(size, false, 0)
        image.draw(in: CGRect(origin: .zero, size: size))
        let resized = UIGraphicsGetImageFromCurrentImageContext() ?? image
        UIGraphicsEndImageContext()
        return resized
    }

    private func aspectFit(_ image: UIImage, maxSize: CGSize) -> UIImage {
        let source = image.size
        guard source.width > 0, source.height > 0 else { return image }
        let scale = min(1, maxSize.width / source.width, maxSize.height / source.height)
        let size = CGSize(width: source.width * scale, height: source.height * scale)
        UIGraphicsBeginImageContextWithOptions(maxSize, false, 0)
        image.draw(in: CGRect(
            x: (maxSize.width - size.width) / 2,
            y: (maxSize.height - size.height) / 2,
            width: size.width,
            height: size.height
        ))
        let fitted = UIGraphicsGetImageFromCurrentImageContext() ?? image
        UIGraphicsEndImageContext()
        return fitted
    }
}
