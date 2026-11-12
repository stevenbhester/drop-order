// Encodes a folder of PNG frames plus a WAV soundtrack into an H.264 + AAC .mp4 (plays on iPhone / in Messages).
//   swiftc -O tools/ads/encode_mp4.swift -o <bin>; <bin> <frames dir> <audio.wav> <out.mp4> [fps] [max MB]
// With a max size, the video is encoded once at a bitrate that fits it (some apps cap attachments) and the
// soundtrack is added without touching the picture again. Without one: 9 Mbps, then a best-quality export.
import AVFoundation
import AppKit

let a = CommandLine.arguments
let dir = URL(fileURLWithPath: a[1]); let wav = URL(fileURLWithPath: a[2]); let out = URL(fileURLWithPath: a[3])
let fps = Int32(a.count > 4 ? a[4] : "30")!
let files = try FileManager.default.contentsOfDirectory(atPath: dir.path).filter { $0.hasSuffix(".png") }.sorted()
func cg(_ f: String) -> CGImage { let i = NSImage(contentsOf: dir.appendingPathComponent(f))!; var r = CGRect(origin: .zero, size: i.size); return i.cgImage(forProposedRect: &r, context: nil, hints: nil)! }
let first = cg(files[0]); let w = first.width, h = first.height
let maxMB: Double? = a.count > 5 ? Double(a[5]) : nil
let seconds = Double(files.count) / Double(fps)
var bitrate = 9_000_000
if let mb = maxMB { bitrate = min(bitrate, Int((mb * 8_000_000 / seconds - 200_000) * 0.95)) }

// 1. Video only.
let silent = out.deletingPathExtension().appendingPathExtension("video.mp4")
try? FileManager.default.removeItem(at: silent)
let writer = try AVAssetWriter(outputURL: silent, fileType: .mp4)
let input = AVAssetWriterInput(mediaType: .video, outputSettings: [AVVideoCodecKey: AVVideoCodecType.h264, AVVideoWidthKey: w, AVVideoHeightKey: h,
	AVVideoCompressionPropertiesKey: [AVVideoAverageBitRateKey: bitrate, AVVideoProfileLevelKey: AVVideoProfileLevelH264HighAutoLevel]])
let ad = AVAssetWriterInputPixelBufferAdaptor(assetWriterInput: input, sourcePixelBufferAttributes: [kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32ARGB, kCVPixelBufferWidthKey as String: w, kCVPixelBufferHeightKey as String: h])
writer.add(input); writer.startWriting(); writer.startSession(atSourceTime: .zero)
for (n, f) in files.enumerated() {
	while !input.isReadyForMoreMediaData { usleep(1000) }
	var pb: CVPixelBuffer?; CVPixelBufferPoolCreatePixelBuffer(nil, ad.pixelBufferPool!, &pb)
	CVPixelBufferLockBaseAddress(pb!, [])
	let ctx = CGContext(data: CVPixelBufferGetBaseAddress(pb!), width: w, height: h, bitsPerComponent: 8, bytesPerRow: CVPixelBufferGetBytesPerRow(pb!), space: CGColorSpaceCreateDeviceRGB(), bitmapInfo: CGImageAlphaInfo.noneSkipFirst.rawValue)!
	autoreleasepool { ctx.draw(cg(f), in: CGRect(x: 0, y: 0, width: w, height: h)) }
	CVPixelBufferUnlockBaseAddress(pb!, [])
	ad.append(pb!, withPresentationTime: CMTime(value: CMTimeValue(n), timescale: fps))
}
input.markAsFinished()
let sem = DispatchSemaphore(value: 0); writer.finishWriting { sem.signal() }; sem.wait()

// 2. Add the soundtrack (AAC), trimmed to the video.
let comp = AVMutableComposition()
let vAsset = AVURLAsset(url: silent); let aAsset = AVURLAsset(url: wav)
let dur = CMTime(value: CMTimeValue(files.count), timescale: fps)
let range = CMTimeRange(start: .zero, duration: dur)
let vt = comp.addMutableTrack(withMediaType: .video, preferredTrackID: kCMPersistentTrackID_Invalid)!
try vt.insertTimeRange(range, of: vAsset.tracks(withMediaType: .video)[0], at: .zero)
let at = comp.addMutableTrack(withMediaType: .audio, preferredTrackID: kCMPersistentTrackID_Invalid)!
let aDur = min(dur, aAsset.duration)
func export(_ asset: AVAsset, _ preset: String, _ url: URL, _ type: AVFileType) -> AVAssetExportSession {
	try? FileManager.default.removeItem(at: url)
	let e = AVAssetExportSession(asset: asset, presetName: preset)!
	e.outputURL = url; e.outputFileType = type
	let s = DispatchSemaphore(value: 0); e.exportAsynchronously { s.signal() }; s.wait()
	return e
}
var ex: AVAssetExportSession
if maxMB != nil {
	// Soundtrack to AAC on its own, then both tracks copied into the mp4 as they are.
	let m4a = out.deletingPathExtension().appendingPathExtension("audio.m4a")
	let only = AVMutableComposition()
	let ot = only.addMutableTrack(withMediaType: .audio, preferredTrackID: kCMPersistentTrackID_Invalid)!
	try ot.insertTimeRange(CMTimeRange(start: .zero, duration: aDur), of: aAsset.tracks(withMediaType: .audio)[0], at: .zero)
	_ = export(only, AVAssetExportPresetAppleM4A, m4a, .m4a)
	let aac = AVURLAsset(url: m4a)
	try at.insertTimeRange(CMTimeRange(start: .zero, duration: min(aDur, aac.duration)), of: aac.tracks(withMediaType: .audio)[0], at: .zero)
	ex = export(comp, AVAssetExportPresetPassthrough, out, .mp4)
	try? FileManager.default.removeItem(at: m4a)
} else {
	try at.insertTimeRange(CMTimeRange(start: .zero, duration: aDur), of: aAsset.tracks(withMediaType: .audio)[0], at: .zero)
	ex = export(comp, AVAssetExportPresetHighestQuality, out, .mp4)
}
try? FileManager.default.removeItem(at: silent)
print("wrote \(out.path): \(files.count) frames at \(fps) fps (\(Double(files.count) / Double(fps)) s), \(w)x\(h), export status \(ex.status.rawValue) \(ex.error?.localizedDescription ?? "")")
