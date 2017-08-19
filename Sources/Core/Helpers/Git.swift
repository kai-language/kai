import CLibGit2

class Progress {
    var progress: git_transfer_progress?
    var completedSteps: Int
    var totalSteps: Int
    var path: String

    init(progress: git_transfer_progress?, completedSteps: Int, totalSteps: Int, path: String) {
        self.progress = progress
        self.completedSteps = completedSteps
        self.totalSteps = totalSteps
        self.path = path
    }
}

class Git {
    init() {
        git_libgit2_init()
    }

    deinit {
        git_libgit2_shutdown()
    }

    static func cloneOptions() -> git_clone_options {
        let optPtr = UnsafeMutablePointer<git_clone_options>.allocate(capacity: 1)
        defer {
            optPtr.deallocate(capacity: 1)
        }

        // TODO(Brett): error checking
        git_clone_init_options(optPtr, UInt32(GIT_CLONE_OPTIONS_VERSION))
        return optPtr.move()
    }

    static func checkoutOptions() -> git_checkout_options {
        let checkPtr = UnsafeMutablePointer<git_checkout_options>.allocate(capacity: 1)
        defer {
            checkPtr.deallocate(capacity: 1)
        }

        // TODO(Brett): error checking
        git_checkout_init_options(checkPtr, UInt32(GIT_CHECKOUT_OPTIONS_VERSION))
        return checkPtr.move()
    }

    func clone(repo repoPath: String, to localPath: String) {
        let repo = UnsafeMutablePointer<OpaquePointer?>.allocate(capacity: 1)
        var cloneOpts = Git.cloneOptions()
        var checkoutOpts = Git.checkoutOptions()

        checkoutOpts.checkout_strategy = GIT_CHECKOUT_SAFE.rawValue
        checkoutOpts.progress_cb = progressCB

        let blockPointer = UnsafeMutablePointer<Progress>.allocate(capacity: 1)
        blockPointer.initialize(to: Progress(progress: nil, completedSteps: 0, totalSteps: 0, path: ""))
        let payloadPtr = UnsafeMutableRawPointer(blockPointer)
        checkoutOpts.progress_payload = payloadPtr

        cloneOpts.checkout_opts = checkoutOpts
        cloneOpts.fetch_opts.callbacks.transfer_progress = fetchProgressCB
        cloneOpts.fetch_opts.callbacks.payload = payloadPtr

        let err = git_clone(
            repo,
            repoPath,
            localPath,
            &cloneOpts
        )

        print() // terminate any progress bars

        if err != 0 {
            if let error = giterr_last() {
                let message = String(cString: error.pointee.message)

                if message.hasSuffix("exists and is not an empty directory") {
                    return
                }
                print(message)
            } else {
                print("An unknown error has occured: \(err)")
            }
        } else if repo.pointee != nil {
            git_repository_free(repo.pointee)
        }
    }
}

func progressCB(path: UnsafePointer<Int8>?, current: Int, total: Int, payload: UnsafeMutableRawPointer?) {
    if let payload = payload {
        let buffer = payload.assumingMemoryBound(to: Progress.self)
        let progress: Progress
        if current < total {
            progress = buffer.pointee
        } else {
            progress = buffer.move()
            buffer.deallocate(capacity: 1)
        }

        progress.totalSteps = total
        progress.completedSteps = current

        printProgress(progress)
    }
}

func fetchProgressCB(stats: UnsafePointer<git_transfer_progress>?, payload: UnsafeMutableRawPointer?) -> Int32 {
    if let payload = payload {
        let buffer = payload.assumingMemoryBound(to: Progress.self)
        let progress = buffer.pointee
        progress.progress = stats?.pointee
        printProgress(progress)
    }

    return 0
}

func printProgress(_ progress: Progress) {
    if let status = progress.progress {
        let net = status.total_objects > 0 ? (100 * status.received_objects) / status.total_objects : 0

        let downloaded = status.received_bytes

        let count = Int(net) / 2

        let blocks = String(repeating: "█", count: count)
        let dashes = String(repeating: " ", count: 50 - count)
        print("\(net.percentPadded) |\(blocks)▏\(dashes)▏ \(downloaded.downloadString)\r", terminator: "")
    } else {
        print("\(progress.completedSteps)/\(progress.totalSteps)\r", terminator: "")
    }

    fflush(stdout)
}

extension Int {
    var downloadString: String {
        var count = self / 1024

        let countString: String

        if count > 1024 {
            count /= 1024
            countString = "\(count)mB"
        } else {
            countString = "\(count)kB"
        }

        let padding: String
        if count < 10 {
            padding = "   "
        } else if count < 100 {
            padding = "  "
        } else if count < 1000 {
            padding = " "
        } else {
            padding = ""
        }

        return countString + padding
    }
}

extension UInt32 {
    var percentPadded: String {
        if self < 10 {
            return "  \(self)%"
        } else if self < 100 {
            return " \(self)%"
        } else {
            return "\(self)%"
        }
    }
}
