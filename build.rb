require "./version"
require "./get-version"

PROGRAM = "crystal-demo"
# VERSION = "v0.1.0"
BUILD_CMD = "crystal build"
SRC_FILES = "app/src/*.cr"
OUTPUT_ARG = "-o"
RELEASE_BUILD = true
RELEASE_ARG = RELEASE_BUILD == true ? "--release" : "--debug"
RELEASE = RELEASE_BUILD == true ? "release" : "debug"
# used in this way:
# BUILD_CMD SRC_FILES RELEASE_ARG TARGET_ARG OUTPUT_ARG OUTPUT_PATH
TEST_CMD = "crystal spec"

ZIG_CC = "zig cc -target"

TARGET_DIR = "target"
DOCKER_DIR = "docker"
UPLOAD_DIR = "upload"

def doCleanAll
    puts "doCleanAll..."
    `rm -rf #{TARGET_DIR} #{UPLOAD_DIR}`
end

def doClean
    puts "doClean..."
    `rm -rf #{TARGET_DIR}/#{DOCKER_DIR} #{UPLOAD_DIR}`
end

# go tool dist list
# linux only for docker
GO_ZIG = {
    "linux/386": ["i386-linux-gnu", "i386-linux-musl"],
    "linux/amd64": ["x86_64-linux-gnu", "x86_64-linux-musl"],
    "linux/arm": ["arm-linux-gnueabi", "arm-linux-gnueabihf", "arm-linux-musleabi", "arm-linux-musleabihf"],
    "linux/arm64": ["aarch64-linux-gnu", "aarch64-linux-musl"],
    "linux/mips": ["mips-linux-gnueabi", "mips-linux-gnueabihf", "mips-linux-musl"],
    "linux/mips64": ["mips64-linux-gnuabi64", "mips64-linux-gnuabin32", "mips64-linux-musl"],
    "linux/mips64le": ["mips64el-linux-gnuabi64", "mips64el-linux-gnuabin32", "mips64el-linux-musl"],
    "linux/mipsle": ["mipsel-linux-gnueabi", "mipsel-linux-gnueabihf", "mipsel-linux-musl"],
    "linux/ppc64": ["powerpc64-linux-gnu", "powerpc64-linux-musl"],
    "linux/ppc64le": ["powerpc64-linux-gnu", "powerpc64-linux-musl"],
    "linux/riscv64": ["riscv64-linux-gnu", "riscv64-linux-musl"],
    "linux/s390x": ["s390x-linux-gnu", "s390x-linux-musl"],
}

ARM = ["5", "6", "7"]

# https://crystal-lang.org/reference/1.6/syntax_and_semantics/platform_support.html
TIER1 = [
    "x86_64-darwin",
    "x86_64-linux-gnu"
]

TIER2 = [
    "aarch64-darwin",
    "aarch64-linux-gnu",
    "aarch64-linux-musl",
    "arm-linux-gnueabihf",
    "i386-linux-gnu",
    "i386-linux-musl",
    "x86_64-linux-musl",
    "x86_64-openbsd",
    "x86_64-freebsd"
]

TIER3 = [
    "x86_64-windows-msvc",
    "x86_64-unknown-dragonfly",
    "x86_64-unknown-netbsd",
    "wasm32-unknown-wasi"
]

TARGETS = TIER1 + TIER2 + TIER3

TEST_TARGETS = TIER1 + TIER2

LESS_TARGETS = TIER1

version = get_version ARGV, 0, VERSION

test_bin = ARGV[0] == "test" || false
less_bin = ARGV[0] == "less" || false

clean_all = ARGV.include? "--clean-all" || false
clean = ARGV.include? "--clean" || false
run_test = ARGV.include? "--run-test" || false
catch_error = ARGV.include? "--catch-error" || false

targets = TARGETS
targets = TEST_TARGETS if test_bin
targets = LESS_TARGETS if less_bin

if clean_all
    doCleanAll
elsif clean
    doClean
    # on local machine, you may re-run this script
elsif test_bin || less_bin
    doClean
end
`mkdir -p #{TARGET_DIR} #{UPLOAD_DIR}`
`mkdir -p #{TARGET_DIR}/#{DOCKER_DIR}`

def existsThen(cmd, src, dest)
    if system "test -f #{src}"
        `#{cmd} #{src} #{dest}`
    end
end

def notExistsThen(cmd, dest, src)
    if not system "test -f #{dest}"
        if system "test -f #{src}"
            cmd = "#{cmd} #{src} #{dest}"
            puts cmd
            IO.popen(cmd) do |r|
                puts r.readlines
            end
        else
            puts "!! #{src} not exists"
        end
    end
end

for target in targets
    tp_array = target.split("-")
    architecture = tp_array[0]
    os = tp_array[1]
    abi = tp_array[2]
    windows = os == "windows"
    
    program_bin = !windows ? PROGRAM : "#{PROGRAM}.exe"
    target_bin = !windows ? target : "#{target}.exe"

    zig_arch = architecture

    zig_os = os
    zig_os = "macos" if os == "darwin"

    zig_abi = abi
    zig_abi = "none" if abi.nil?

    zig_target_arg = "#{zig_arch}-#{zig_os}-#{zig_abi}"
    target_arg = "--cross-compile --target #{target}"

    dir = "#{TARGET_DIR}/#{target}/#{RELEASE}"
    `mkdir -p #{dir}`

    cmd = "export CC='#{ZIG_CC} #{zig_target_arg}' && #{BUILD_CMD} #{SRC_FILES} #{RELEASE_ARG} #{target_arg} #{OUTPUT_ARG} #{dir}/#{PROGRAM}"
    puts cmd

    result = `#{cmd}`
    puts result
    puts

    existsThen "ln", "#{TARGET_DIR}/#{target}/#{RELEASE}/#{program_bin}", "#{UPLOAD_DIR}/#{target_bin}"
end

GO_ZIG.each do |target_platform, targets|
    tp_array = target_platform.to_s.split("/")
    os = tp_array[0]
    architecture = tp_array[1]

    if architecture == "arm"
        for variant in ARM
            docker = "#{TARGET_DIR}/#{DOCKER_DIR}/#{os}/#{architecture}/v#{variant}"
            puts docker
            `mkdir -p #{docker}`

            if targets.kind_of?(Array)
                for target in targets
                    tg_array = target.split("-")
                    abi = tg_array.last

                    existsThen "ln", "#{TARGET_DIR}/#{target}/#{RELEASE}/#{PROGRAM}", "#{docker}/#{PROGRAM}-#{abi}"
                    Dir.chdir docker do
                        notExistsThen "ln -s", PROGRAM, "#{PROGRAM}-#{abi}"
                    end
                end
            else
                existsThen "ln", "#{TARGET_DIR}/#{target}/#{RELEASE}/#{PROGRAM}", "#{docker}/#{PROGRAM}"
            end
        end
    else
        docker = "#{TARGET_DIR}/#{DOCKER_DIR}/#{os}/#{architecture}"
        puts docker
        `mkdir -p #{docker}`

        if targets.kind_of?(Array)
            for target in targets
                tg_array = target.split("-")
                abi = tg_array.last

                existsThen "ln", "#{TARGET_DIR}/#{target}/#{RELEASE}/#{PROGRAM}", "#{docker}/#{PROGRAM}-#{abi}"
                Dir.chdir docker do
                    notExistsThen "ln -s", PROGRAM, "#{PROGRAM}-#{abi}"
                end
            end
        else
            existsThen "ln", "#{TARGET_DIR}/#{target}/#{RELEASE}/#{PROGRAM}", "#{docker}/#{PROGRAM}"
        end
    end
end

# cmd = "file #{UPLOAD_DIR}/**"
# IO.popen(cmd) do |r|
#         puts r.readlines
# end

file = "#{UPLOAD_DIR}/BINARYS"
IO.write(file, "")

cmd = "tree #{TARGET_DIR}/#{DOCKER_DIR}"
IO.popen(cmd) do |r|
    rd = r.readlines
    puts rd

    for o in rd
        IO.write(file, o, mode: "a")
    end
end

Dir.chdir UPLOAD_DIR do
    file = "SHA256SUM"
    IO.write(file, "")

    cmd = "sha256sum *"
    IO.popen(cmd) do |r|
        rd = r.readlines

        for o in rd
            if !o.include? "SHA256SUM" and !o.include? "BINARYS"
                print o
                IO.write(file, o, mode: "a")
            end
        end
    end
end

# `docker buildx build --platform linux/amd64 -t demo:amd64 . --load`
# cmd = "docker run demo:amd64"
# IO.popen(cmd) do |r|
#         puts r.readlines
# end
