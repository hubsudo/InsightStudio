import AVKit
import UIKit
import Combine

final class VideoDetailViewController: UIViewController {
    private let video: VideoSummary
    private let context: AppContext

    private let playerContainer = UIView()
    private let statusLabel: UILabel = {
        let label = UILabel()
        label.numberOfLines = 0
        label.font = .systemFont(ofSize: 13)
        label.textColor = .secondaryLabel
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()

    private let importButton: UIButton = {
        let button = UIButton(type: .system)
        button.setTitle("导入到剪辑库", for: .normal)
        button.titleLabel?.font = .systemFont(ofSize: 17, weight: .semibold)
        button.translatesAutoresizingMaskIntoConstraints = false
        return button
    }()

    private var playerViewController: AVPlayerViewController?
    private var currentPlaybackInfo: StreamPlaybackInfo?

    init(video: VideoSummary, context: AppContext) {
        self.video = video
        self.context = context
        super.init(nibName: nil, bundle: nil)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        title = "视频预览"
        view.backgroundColor = .systemBackground
        setupUI()
        resolvePlayback()
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        detachPlayer()
    }

    private func setupUI() {
        playerContainer.translatesAutoresizingMaskIntoConstraints = false
        importButton.addTarget(self, action: #selector(importClip), for: .touchUpInside)

        view.addSubview(playerContainer)
        view.addSubview(statusLabel)
        view.addSubview(importButton)

        NSLayoutConstraint.activate([
            playerContainer.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            playerContainer.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            playerContainer.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 16),
            playerContainer.heightAnchor.constraint(equalTo: playerContainer.widthAnchor, multiplier: 9.0/16.0),

            statusLabel.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 16),
            statusLabel.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -16),
            statusLabel.topAnchor.constraint(equalTo: playerContainer.bottomAnchor, constant: 16),

            importButton.topAnchor.constraint(equalTo: statusLabel.bottomAnchor, constant: 20),
            importButton.centerXAnchor.constraint(equalTo: view.centerXAnchor)
        ])
    }

    private func resolvePlayback() {
        statusLabel.text = "正在向后端请求可播放流..."
        Task { [weak self] in
            guard let self else { return }
            do {
                let info = try await context.streamPlaybackService.resolvePlayback(videoId: video.videoId)
                currentPlaybackInfo = info
                statusLabel.text = "标题：\(info.title)\nExtractor: \(info.extractor ?? "unknown")"
                attachPlayer(urlString: info.streamURL)
            } catch {
                statusLabel.text = "播放地址解析失败：\(error.localizedDescription)"
            }
        }
    }

    private func attachPlayer(urlString: String) {
        detachPlayer()
        guard let player = PlayerFactory.makePlayer(urlString: urlString) else { return }
        let pvc = AVPlayerViewController()
        pvc.player = player
        addChild(pvc)
        pvc.view.translatesAutoresizingMaskIntoConstraints = false
        playerContainer.addSubview(pvc.view)
        NSLayoutConstraint.activate([
            pvc.view.leadingAnchor.constraint(equalTo: playerContainer.leadingAnchor),
            pvc.view.trailingAnchor.constraint(equalTo: playerContainer.trailingAnchor),
            pvc.view.topAnchor.constraint(equalTo: playerContainer.topAnchor),
            pvc.view.bottomAnchor.constraint(equalTo: playerContainer.bottomAnchor)
        ])
        pvc.didMove(toParent: self)
        player.play()
        playerViewController = pvc
    }
    
    private func detachPlayer() {
        guard let pvc = playerViewController else { return }

        pvc.player?.pause()
        pvc.player?.replaceCurrentItem(with: nil)
        pvc.player = nil

        pvc.willMove(toParent: nil)
        pvc.view.removeFromSuperview()
        pvc.removeFromParent()

        playerViewController = nil
    }

    @objc private func importClip() {
        Task { [weak self] in
            guard let self else { return }

            do {
                try await self.importClipAsync()
            } catch {
                await MainActor.run {
                    let alert = UIAlertController(
                        title: "导入失败",
                        message: error.localizedDescription,
                        preferredStyle: .alert
                    )
                    alert.addAction(UIAlertAction(title: "OK", style: .default))
                    self.present(alert, animated: true)
                }
            }
        }
    }
    
    private func importClipAsync() async throws {
        guard let info = currentPlaybackInfo else {
            throw NSError(
                domain: "Import",
                code: -1,
                userInfo: [NSLocalizedDescriptionKey: "缺少播放信息"]
            )
        }

        let assetID = UUID().uuidString

        guard let remoteURL = URL(string: info.streamURL) else {
            throw NSError(
                domain: "Import",
                code: -2,
                userInfo: [NSLocalizedDescriptionKey: "无效的视频地址"]
            )
        }
        
        let estimatedDuration = Double(info.durationSeconds ?? 15)
        let initialSelectedEnd = Double(min(info.durationSeconds ?? 15, 15))

        var clip = ImportedClip(
            sourceID: assetID,
            videoId: video.videoId,
            title: video.title,
            thumbnailURL: video.thumbnailURL,
            remoteStreamURL: info.streamURL,
            localFileURL: nil,
            durationSeconds: estimatedDuration,
            selectedStartSeconds: 0,
            selectedEndSeconds: initialSelectedEnd,
            downloadState: .downloading,
            downloadProgress: 0,
            lastErrorMessage: nil
        )
        context.clipLibraryRepository.save(clip)
        context.importSignalCenter.importedClip.send(.inserted(clip))

        await MainActor.run {
            let alert = UIAlertController(
                title: "开始导入",
                message: "素材已加入 Editor 工作台，正在后台下载",
                preferredStyle: .alert
            )
            alert.addAction(UIAlertAction(title: "OK", style: .default))
            self.present(alert, animated: true)
        }
        
        let dispatcher = await MainActor.run {
            ClipImportEventDispatcher(
                repository: context.clipLibraryRepository,
                signalCenter: context.importSignalCenter
            )
        }
        
        do {
            let clipID = clip.id
            
            let localURL = try await context.clipDownloadService.downloadVideo(from: remoteURL, assetID: assetID) { event in
                switch event {
                case .progress(let progress):
                    Task { @MainActor in
                        dispatcher.emitProgress(for: clipID, progress: progress)
                    }
                case .completed:
                    break
                }
            }
            
            let asset = AVURLAsset(url: localURL)
            let duration = try await asset.load(.duration)
            let durationSeconds = duration.seconds
            
            guard durationSeconds.isFinite, durationSeconds > 0 else {
                throw NSError(
                    domain: "Import",
                    code: -3,
                    userInfo: [NSLocalizedDescriptionKey: "本地视频时长无效"]
                )
            }

            context.clipLibraryRepository.markReady(
                for: clip.id,
                localFileURL: localURL,
                durationSeconds: durationSeconds
            )
            
            clip.localFileURL = localURL
            clip.durationSeconds = durationSeconds
            clip.downloadState = .ready
            clip.downloadProgress = 1.0
            clip.lastErrorMessage = nil
            
            context.importSignalCenter.importedClip.send(.updated(clip))
        } catch {
            dispatcher.emitFailure(for: clip.id, message: error.localizedDescription)
            throw error
        }
    }
}
