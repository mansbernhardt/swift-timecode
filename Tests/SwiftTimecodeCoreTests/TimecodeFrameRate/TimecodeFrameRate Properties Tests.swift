//
//  TimecodeFrameRate Properties Tests.swift
//  swift-timecode • https://github.com/orchetect/swift-timecode
//  © 2026 Steffan Andrews • Licensed under MIT License
//

@testable import SwiftTimecodeCore
import Testing

@Suite
struct TimecodeFrameRate_Properties_Tests {
    @Test
    func properties() {
        // spot-check that properties behave as expected

        let frameRate: TimecodeFrameRate = .fps30

        #expect(frameRate.stringValue == "30")

        #expect(frameRate.stringValueVerbose == "30 fps")

        #expect(TimecodeFrameRate(stringValue: "30") == frameRate)

        #expect(frameRate.numberOfDigits == 2)

        #expect(frameRate.maxFrameNumberDisplayable == 29)

        #expect(
            frameRate.maxTotalFrames(in: .max24Hours)
                == 2_592_000
        )

        #expect(
            frameRate.maxTotalFrames(in: .max100Days)
                == 2_592_000 * 100
        )

        #expect(
            frameRate.maxTotalFramesExpressible(in: .max24Hours)
                == 2_592_000 - 1
        )

        #expect(
            frameRate.maxTotalFramesExpressible(in: .max100Days)
                == (2_592_000 * 100) - 1
        )

        #expect(
            frameRate.maxTotalSubFrames(
                in: .max24Hours,
                base: .max80SubFrames
            )
                == 2_592_000 * 80
        )

        // these integers result in overflow on armv7/i386 (32-bit arch)
        #if !(arch(arm) || arch(i386))
        #expect(
            frameRate.maxTotalSubFrames(
                in: .max100Days,
                base: .max80SubFrames
            )
                == 2_592_000 * 100 * 80
        )

        #expect(
            frameRate.maxSubFrameCountExpressible(
                in: .max100Days,
                base: .max80SubFrames
            )
                == (2_592_000 * 100 * 80) - 1
        )
        #endif

        #expect(
            frameRate.maxSubFrameCountExpressible(
                in: .max24Hours,
                base: .max80SubFrames
            )
                == (2_592_000 * 80) - 1
        )

        #expect(frameRate.maxFrames == 30)

        #expect(frameRate.frameRateForElapsedFramesCalculation == 30.0)

        #expect(frameRate.frameRateForRealTimeCalculation == 30.0)

        #expect(frameRate.framesDroppedPerMinute == 0.0)
    }

    /// `.max100Days` subframe counts must not overflow on a 32-bit platform.
    ///
    /// These counts are `Int64` rather than `Int` because at `.max100Days` the
    /// product exceeds `Int32.max` for every frame rate at the 80- and
    /// 100-subframe bases — the smallest such case, 23.976 fps at 80 subframes,
    /// is already `2_073_600 * 100 * 80 = 16_588_800_000`. (At the
    /// `.quarterFrames` base the lower rates do still fit, which is exactly why
    /// this is asserted across every rate/base pair rather than spot-checked.) As plain `Int` this trapped on wasm32 and on watchOS
    /// armv7k/arm64_32, and because the bound is recomputed inside every
    /// wrapping add it took ALL arithmetic on a `.max100Days` timecode with it,
    /// however small the operands.
    @Test
    func maxTotalSubFramesFitsOn32Bit() {
        for frameRate in TimecodeFrameRate.allCases {
            for base in Timecode.SubFramesBase.allCases {
                let total = frameRate.maxTotalSubFrames(in: .max100Days, base: base)
                #expect(total == Int64(frameRate.maxTotalFrames(in: .max100Days)) * Int64(base.rawValue))
                #expect(frameRate.maxSubFrameCountExpressible(in: .max100Days, base: base) == total - 1)
            }
        }
    }

    /// Arithmetic on a `.max100Days` timecode must work on every platform.
    ///
    /// The regression this guards is not about large values — these operands are
    /// tiny. It is the upper BOUND, recomputed on each wrapping add.
    @Test
    func max100DaysArithmeticDoesNotTrap() throws {
        var lhs = try Timecode(.realTime(seconds: 1.0), at: .fps59_94)
        var rhs = try Timecode(.realTime(seconds: 192.0), at: .fps59_94)
        lhs.properties.upperLimit = .max100Days
        rhs.properties.upperLimit = .max100Days

        let sum = try lhs.adding(rhs, by: .wrapping)
        #expect(sum.components.minutes == 3)
        #expect(sum.components.seconds == 12)
    }

    @Test
    func initStringValue() {
        #expect(TimecodeFrameRate(stringValue: "23.976") == .fps23_976)
        #expect(TimecodeFrameRate(stringValue: "29.97d") == .fps29_97d)

        #expect(TimecodeFrameRate(stringValue: "") == nil)
        #expect(TimecodeFrameRate(stringValue: " ") == nil)
        #expect(TimecodeFrameRate(stringValue: "BogusString") == nil)
    }
}
