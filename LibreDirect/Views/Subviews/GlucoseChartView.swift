//
//  GlucoseChartView.swift
//  LibreDirect
//
//  Created by Reimar Metzen on 26.07.21.
//

import Combine
import SwiftUI

// MARK: - SensorGlucose + Equatable

extension SensorGlucose: Equatable {
    static func == (lhs: SensorGlucose, rhs: SensorGlucose) -> Bool {
        lhs.timestamp == rhs.timestamp
    }
}

extension Date {
    static func dates(from fromDate: Date, to toDate: Date) -> [Date] {
        var dates: [Date] = []
        var date = fromDate

        while date <= toDate {
            dates.append(date)
            guard let newDate = Calendar.current.date(byAdding: .minute, value: 15, to: date) else {
                break
            }
            date = newDate
        }

        return dates
    }
}

// MARK: - TextInfo

struct TextInfo {
    let description: String
    let x: CGFloat
    let y: CGFloat
    let highlight: Bool
}

// MARK: - GlucoseChartView

struct GlucoseChartView: View {
    private let calculationQueue = DispatchQueue(label: "libre-direct.chart-calculation")
    private let timer = Timer.publish(every: 10, on: .main, in: .default).autoconnect()

    private enum Config {
        static let alarmGridColor = Color.red.opacity(0.5)
        static let alarmStrokeStyle = StrokeStyle(lineWidth: 0.2, dash: [8])
        static let dotDarkColor = Color.white.opacity(0.65)
        static let dotLightColor = Color.black.opacity(0.65)
        static let dotSize: CGFloat = 4
        static let endID = "End"
        static let height: CGFloat = 350
        static let maxGlucose = 350
        static let minGlucose = 0
        static let targetGridColor = Color.green.opacity(0.5)
        static let targetStrokeStyle = StrokeStyle(lineWidth: 0.2, dash: [8])
        static let xGridColor = Color.secondary.opacity(0.25)
        static let xGridFontSize: CGFloat = 12
        static let xGridStrokeStyle = StrokeStyle(lineWidth: 0.2)
        static let xStep: CGFloat = 5 // Config.dotSize
        static let yAdditionalBottom: CGFloat = Config.yGridFontSize * 2
        static let yGridColor = Color.secondary.opacity(0.25)
        static let yGridFontSize: CGFloat = 12
        static let yGridFontWidth: CGFloat = 28
        static let yGridPadding: CGFloat = 20
        static let yGridStrokeStyle = StrokeStyle(lineWidth: 0.2)
        static let nowColor = Color.blue.opacity(0.25)
        static let nowStrokeStyle = StrokeStyle(lineWidth: 0.2, dash: [8])
        static let yStep = 50
    }

    @Environment(\.colorScheme) var colorScheme
    @Environment(\.scenePhase) var scenePhase

    @State var alarmHighGridPath = Path()
    @State var alarmLowGridPath = Path()
    @State var firstTimeStamp: Date? = nil
    @State var glucoseDotsPath = Path()
    @State var glucoseMinutes: Int = 0
    @State var lastTimeStamp: Date? = nil
    @State var targetGridPath = Path()
    @State var xGridPath = Path()
    @State var xGridTexts: [TextInfo] = []
    @State var nowPath = Path()
    @State var yGridPath = Path()
    @State var yGridTexts: [TextInfo] = []
    @State var deviceOrientation: UIDeviceOrientation? = UIDevice.current.orientation

    var glucoseValues: [SensorGlucose]
    var glucoseUnit: GlucoseUnit
    var alarmLow: Int?
    var alarmHigh: Int?
    var targetValue: Int?

    var dotColor: Color {
        if colorScheme == .dark {
            return Config.dotDarkColor
        }

        return Config.dotLightColor
    }

    var body: some View {
        if !glucoseValues.isEmpty {
            GroupBox(label: Text(String(format: LocalizedString("Chart (%1$@)", comment: ""), glucoseValues.count.description)).padding(.bottom).foregroundColor(.accentColor)) {
                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        yGridView()
                        alarmLowGridView()
                        alarmHighGridView()
                        targetGridView()
                        scrollGridView().padding(.leading, Config.yGridPadding)
                    }
                    .onReceive(timer) { _ in
                        Log.info("onReceive: \(timer)")

                        updateNowPath(fullSize: geo.size)
                    }
                    .onChange(of: scenePhase) { state in
                        if state == .active {
                            Log.info("onChange: \(state)")
                            updateHelpVariables(fullSize: geo.size, glucoseValues: self.glucoseValues)

                            updateYGrid(fullSize: geo.size, alarmLow: self.alarmLow, alarmHigh: self.alarmHigh, targetValue: self.targetValue, glucoseUnit: self.glucoseUnit)
                            updateAlarmLowGrid(fullSize: geo.size, alarmLow: self.alarmLow)
                            updateAlarmHighGrid(fullSize: geo.size, alarmHigh: self.alarmHigh)
                            updateTargetGrid(fullSize: geo.size, targetValue: self.targetValue)

                            updateXGrid(fullSize: geo.size, firstTimeStamp: self.firstTimeStamp, lastTimeStamp: self.lastTimeStamp)
                            updateGlucoseDots(fullSize: geo.size, glucoseValues: self.glucoseValues)
                        }
                    }
                    .onRotate { rotation in
                        if deviceOrientation != rotation, rotation != .unknown {
                            deviceOrientation = rotation

                            Log.info("onRotate: \(rotation)")

                            updateYGrid(fullSize: geo.size, alarmLow: self.alarmLow, alarmHigh: self.alarmHigh, targetValue: self.targetValue, glucoseUnit: self.glucoseUnit)
                            updateAlarmLowGrid(fullSize: geo.size, alarmLow: self.alarmLow)
                            updateAlarmHighGrid(fullSize: geo.size, alarmHigh: self.alarmHigh)
                            updateTargetGrid(fullSize: geo.size, targetValue: self.targetValue)
                        }
                    }
                    .onChange(of: alarmLow) { alarmLow in
                        Log.info("onChange: \(alarmLow)")

                        updateYGrid(fullSize: geo.size, alarmLow: alarmLow, alarmHigh: self.alarmHigh, targetValue: self.targetValue, glucoseUnit: self.glucoseUnit)
                        updateAlarmLowGrid(fullSize: geo.size, alarmLow: alarmLow)
                    }
                    .onChange(of: alarmHigh) { alarmHigh in
                        Log.info("onChange: \(alarmHigh)")

                        updateYGrid(fullSize: geo.size, alarmLow: self.alarmLow, alarmHigh: alarmHigh, targetValue: self.targetValue, glucoseUnit: self.glucoseUnit)
                        updateAlarmHighGrid(fullSize: geo.size, alarmHigh: alarmHigh)
                    }
                    .onChange(of: targetValue) { targetValue in
                        Log.info("onChange: \(targetValue)")

                        updateYGrid(fullSize: geo.size, alarmLow: self.alarmLow, alarmHigh: self.alarmHigh, targetValue: targetValue, glucoseUnit: self.glucoseUnit)
                        updateTargetGrid(fullSize: geo.size, targetValue: targetValue)
                    }
                    .onChange(of: glucoseUnit) { glucoseUnit in
                        Log.info("onChange: \(glucoseUnit)")

                        updateYGrid(fullSize: geo.size, alarmLow: self.alarmLow, alarmHigh: self.alarmHigh, targetValue: self.targetValue, glucoseUnit: glucoseUnit)
                    }
                    .onChange(of: glucoseValues) { glucoseValues in
                        Log.info("onChange: \(glucoseValues.count)")

                        updateHelpVariables(fullSize: geo.size, glucoseValues: glucoseValues)

                        updateNowPath(fullSize: geo.size)
                        updateXGrid(fullSize: geo.size, firstTimeStamp: self.firstTimeStamp, lastTimeStamp: self.lastTimeStamp)
                        updateGlucoseDots(fullSize: geo.size, glucoseValues: glucoseValues)
                    }.onAppear {
                        Log.info("onAppear")

                        updateNowPath(fullSize: geo.size)
                        updateHelpVariables(fullSize: geo.size, glucoseValues: self.glucoseValues)

                        updateYGrid(fullSize: geo.size, alarmLow: self.alarmLow, alarmHigh: self.alarmHigh, targetValue: self.targetValue, glucoseUnit: self.glucoseUnit)
                        updateAlarmLowGrid(fullSize: geo.size, alarmLow: self.alarmLow)
                        updateAlarmHighGrid(fullSize: geo.size, alarmHigh: self.alarmHigh)
                        updateTargetGrid(fullSize: geo.size, targetValue: self.targetValue)

                        updateXGrid(fullSize: geo.size, firstTimeStamp: self.firstTimeStamp, lastTimeStamp: self.lastTimeStamp)
                        updateGlucoseDots(fullSize: geo.size, glucoseValues: self.glucoseValues)
                    }
                }
            }.frame(height: Config.height)
        }
    }

    private func scrollGridView() -> some View {
        ScrollView(.horizontal, showsIndicators: false) {
            ScrollViewReader { scroll in
                ZStack {
                    xGridView()
                    glucoseDotsView()
                    nowView()
                }
                .id(Config.endID)
                .frame(width: CGFloat(glucoseMinutes) * Config.xStep)
                .onChange(of: glucoseValues) { _ in
                    scroll.scrollTo(Config.endID, anchor: .trailing)
                }
                .onAppear {
                    DispatchQueue.main.async {
                        scroll.scrollTo(Config.endID, anchor: .trailing)
                    }
                }
            }
        }
    }

    private func alarmHighGridView() -> some View {
        alarmHighGridPath
            .stroke(style: Config.alarmStrokeStyle)
            .stroke(Config.alarmGridColor)
    }

    private func alarmLowGridView() -> some View {
        alarmLowGridPath
            .stroke(style: Config.alarmStrokeStyle)
            .stroke(Config.alarmGridColor)
    }

    private func nowView() -> some View {
        nowPath
            .stroke(style: Config.nowStrokeStyle)
            .stroke(Config.nowColor)
    }

    private func glucoseDotsView() -> some View {
        glucoseDotsPath
            .fill(dotColor)
    }

    private func targetGridView() -> some View {
        targetGridPath
            .stroke(style: Config.targetStrokeStyle)
            .stroke(Config.targetGridColor)
    }

    private func xGridView() -> some View {
        ZStack {
            xGridPath
                .stroke(style: Config.xGridStrokeStyle)
                .stroke(Config.xGridColor)

            ForEach(xGridTexts, id: \.self.x) { text in
                let fontWeight: Font.Weight = text.highlight ? .bold : .light

                Text(text.description)
                    .font(.system(size: Config.xGridFontSize))
                    .fontWeight(fontWeight)
                    .position(x: text.x, y: text.y)
            }
        }
    }

    private func yGridView() -> some View {
        ZStack {
            yGridPath
                .stroke(style: Config.yGridStrokeStyle)
                .stroke(Config.yGridColor)

            ForEach(yGridTexts, id: \.self.y) { text in
                let fontWeight: Font.Weight = text.highlight ? .bold : .light

                Text(text.description)
                    .font(.system(size: Config.yGridFontSize))
                    .fontWeight(fontWeight)
                    .padding(0)
                    .frame(width: Config.yGridFontWidth, alignment: .trailing)
                    .position(x: text.x, y: text.y)
            }
        }
    }

    private func updateHelpVariables(fullSize: CGSize, glucoseValues: [SensorGlucose]) {
        if let first = glucoseValues.first {
            let firstTimeStamp = first.timestamp.addingTimeInterval(-1 * 15 * 60)
            let lastTimeStamp = Date().rounded(on: 1, .minute).addingTimeInterval(15 * 60)
            let glucoseMinutes = Int(firstTimeStamp.distance(to: lastTimeStamp) / 60)

            self.firstTimeStamp = firstTimeStamp
            self.lastTimeStamp = lastTimeStamp
            self.glucoseMinutes = glucoseMinutes
        }
    }

    private func updateAlarmHighGrid(fullSize: CGSize, alarmHigh: Int?) {
        calculationQueue.async {
            if let alarmHigh = alarmHigh {
                let alarmHighGridPath = Path { path in
                    let y = self.translateGlucoseToY(fullSize: fullSize, glucose: CGFloat(alarmHigh))

                    path.move(to: CGPoint(x: Config.yGridPadding, y: y))
                    path.addLine(to: CGPoint(x: fullSize.width, y: y))
                }

                DispatchQueue.main.async {
                    self.alarmHighGridPath = alarmHighGridPath
                }
            }
        }
    }

    private func updateAlarmLowGrid(fullSize: CGSize, alarmLow: Int?) {
        calculationQueue.async {
            if let alarmLow = alarmLow {
                let alarmLowGridPath = Path { path in
                    let y = self.translateGlucoseToY(fullSize: fullSize, glucose: CGFloat(alarmLow))

                    path.move(to: CGPoint(x: Config.yGridPadding, y: y))
                    path.addLine(to: CGPoint(x: fullSize.width, y: y))
                }

                DispatchQueue.main.async {
                    self.alarmLowGridPath = alarmLowGridPath
                }
            }
        }
    }

    private func updateNowPath(fullSize: CGSize) {
        calculationQueue.async {
            var now: Date?

            #if targetEnvironment(simulator)
                now = ISO8601DateFormatter().date(from: "2021-08-01T11:50:00+0200")
            #else
                now = Date().rounded(on: 1, .minute)
            #endif

            if let now = now {
                let x = self.translateTimeStampToX(timestamp: now)

                var nowPath = Path()
                nowPath.move(to: CGPoint(x: x, y: 0))
                nowPath.addLine(to: CGPoint(x: x, y: fullSize.height - Config.yAdditionalBottom))

                DispatchQueue.main.async {
                    self.nowPath = nowPath
                }
            }
        }
    }

    private func updateGlucoseDots(fullSize: CGSize, glucoseValues: [SensorGlucose]) {
        calculationQueue.async {
            let glucoseDotsPath = Path { path in
                for value in glucoseValues {
                    let x = self.translateTimeStampToX(timestamp: value.timestamp)
                    let y = self.translateGlucoseToY(fullSize: fullSize, glucose: CGFloat(value.glucoseValue))

                    path.addEllipse(in: CGRect(x: x - Config.dotSize / 2, y: y - Config.dotSize / 2, width: Config.dotSize, height: Config.dotSize))
                }
            }

            DispatchQueue.main.async {
                self.glucoseDotsPath = glucoseDotsPath
            }
        }
    }

    private func updateTargetGrid(fullSize: CGSize, targetValue: Int?) {
        calculationQueue.async {
            if let targetValue = targetValue {
                let targetGridPath = Path { path in
                    let y = self.translateGlucoseToY(fullSize: fullSize, glucose: CGFloat(targetValue))

                    path.move(to: CGPoint(x: Config.yGridPadding, y: y))
                    path.addLine(to: CGPoint(x: fullSize.width, y: y))
                }

                DispatchQueue.main.async {
                    self.targetGridPath = targetGridPath
                }
            }
        }
    }

    private func updateXGrid(fullSize: CGSize, firstTimeStamp: Date?, lastTimeStamp: Date?) {
        calculationQueue.async {
            if let firstTimeStamp = firstTimeStamp, let lastTimeStamp = lastTimeStamp {
                let allHours = Date.dates(from: firstTimeStamp.rounded(on: 15, .minute).addingTimeInterval(-1 * 120 * 60), to: lastTimeStamp.addingTimeInterval(120 * 60))

                let xGridPath = Path { path in
                    for hour in allHours {
                        path.move(to: CGPoint(x: self.translateTimeStampToX(timestamp: hour), y: 0))
                        path.addLine(to: CGPoint(x: self.translateTimeStampToX(timestamp: hour), y: fullSize.height - Config.yAdditionalBottom))
                    }
                }

                var xGridTexts: [TextInfo] = []
                for hour in allHours {
                    let highlight = Calendar.current.component(.minute, from: hour) == 0
                    let x = self.translateTimeStampToX(timestamp: hour)
                    let y = fullSize.height - Config.yGridFontSize
                    xGridTexts.append(TextInfo(description: hour.localTime, x: x, y: y, highlight: highlight))
                }

                DispatchQueue.main.async {
                    self.xGridPath = xGridPath
                    self.xGridTexts = xGridTexts
                }
            }
        }
    }

    private func updateYGrid(fullSize: CGSize, alarmLow: Int?, alarmHigh: Int?, targetValue: Int?, glucoseUnit: GlucoseUnit) {
        calculationQueue.async {
            let gridParts = stride(from: Config.minGlucose, to: Config.maxGlucose + 1, by: Config.yStep)

            let yGridPath = Path { path in
                for i in gridParts {
                    if i == alarmLow || i == alarmHigh || i == targetValue {
                        continue
                    }

                    let y = self.translateGlucoseToY(fullSize: fullSize, glucose: CGFloat(i))

                    path.move(to: CGPoint(x: Config.yGridPadding, y: y))
                    path.addLine(to: CGPoint(x: fullSize.width, y: y))
                }
            }

            var yGridTexts: [TextInfo] = []
            for i in gridParts {
                if i < AppConfig.MinReadableGlucose {
                    continue
                }

                let y = self.translateGlucoseToY(fullSize: fullSize, glucose: CGFloat(i))
                yGridTexts.append(TextInfo(description: i.asGlucose(unit: glucoseUnit), x: 0, y: y, highlight: false))
            }

            DispatchQueue.main.async {
                self.yGridPath = yGridPath
                self.yGridTexts = yGridTexts
            }
        }
    }

    private func translateGlucoseToY(fullSize: CGSize, glucose: CGFloat) -> CGFloat {
        let inMin = CGFloat(Config.minGlucose)
        let inMax = CGFloat(Config.maxGlucose)
        let outMin = fullSize.height - Config.yAdditionalBottom
        let outMax = CGFloat(0)

        let y = (glucose - inMin) * (outMax - outMin) / (inMax - inMin) + outMin
        return y
    }

    private func translateMinuteToX(minute: Int) -> CGFloat {
        return CGFloat(minute) * Config.xStep
    }

    private func translateTimeStampToX(timestamp: Date) -> CGFloat {
        if let first = firstTimeStamp {
            let minute = Int(first.distance(to: timestamp) / 60)

            return translateMinuteToX(minute: minute)
        }

        return 0
    }
}

// MARK: - GlucoseChartView_Previews

struct GlucoseChartView_Previews: PreviewProvider {
    static var previews: some View {
        let dateFormatter = ISO8601DateFormatter()

        let glucoseValues = [
            SensorGlucose(id: 1, timestamp: dateFormatter.date(from: "2021-08-01T10:00:00+0200")!, glucose: 70),
            SensorGlucose(id: 2, timestamp: dateFormatter.date(from: "2021-08-01T10:15:00+0200")!, glucose: 100),
            SensorGlucose(id: 3, timestamp: dateFormatter.date(from: "2021-08-01T10:30:00+0200")!, glucose: 180),
            SensorGlucose(id: 4, timestamp: dateFormatter.date(from: "2021-08-01T10:45:00+0200")!, glucose: 250),
            SensorGlucose(id: 5, timestamp: dateFormatter.date(from: "2021-08-01T11:00:00+0200")!, glucose: 70),
            SensorGlucose(id: 6, timestamp: dateFormatter.date(from: "2021-08-01T11:05:00+0200")!, glucose: 100),
            SensorGlucose(id: 7, timestamp: dateFormatter.date(from: "2021-08-01T11:10:00+0200")!, glucose: 180),
            SensorGlucose(id: 8, timestamp: dateFormatter.date(from: "2021-08-01T11:15:00+0200")!, glucose: 250),
            SensorGlucose(id: 9, timestamp: dateFormatter.date(from: "2021-08-01T12:00:00+0200")!, glucose: 70),
            SensorGlucose(id: 10, timestamp: dateFormatter.date(from: "2021-08-01T12:01:00+0200")!, glucose: 70),
            SensorGlucose(id: 11, timestamp: dateFormatter.date(from: "2021-08-01T12:02:00+0200")!, glucose: 70),
            SensorGlucose(id: 12, timestamp: dateFormatter.date(from: "2021-08-01T12:03:00+0200")!, glucose: 70)
        ]

        ForEach(ColorScheme.allCases, id: \.self) {
            GlucoseChartView(glucoseValues: glucoseValues, glucoseUnit: .mgdL, alarmLow: 70, alarmHigh: 180, targetValue: 100).preferredColorScheme($0)
            GlucoseChartView(glucoseValues: glucoseValues, glucoseUnit: .mmolL, alarmLow: 70, alarmHigh: 180, targetValue: 100).preferredColorScheme($0)
        }
    }
}
