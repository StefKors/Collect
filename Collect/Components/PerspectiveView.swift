//
//  PerspectiveView.swift
//  Collect
//
//  Created by Stef Kors on 12/03/2024.
//

import SwiftUI

struct PerpectiveInfo: Codable, Hashable {
    let degrees: Double
    let pointX: Double
    let pointY: Double
}

private struct PerspectiveInfoKey: EnvironmentKey {
    static let defaultValue = PerpectiveInfo(degrees: 0, pointX: 0, pointY: 0)
}

extension EnvironmentValues {
    var perspectiveInfo: PerpectiveInfo {
        get { self[PerspectiveInfoKey.self] }
        set { self[PerspectiveInfoKey.self] = newValue }
    }
}


struct PerspectiveView: View {
    @State private var perspective = PerpectiveInfo(degrees: 0, pointX: 0, pointY: 0)
    @State private var draging: Bool = false

    var body: some View {
        GeometryReader { proxy in
            ZStack {

                // todo replace with viewmodifier?
                ElementRectView(label: "group", level: 0, origin: .init(x: 120, y: 120), size: CGSize(width: 200, height: 80), showCollect: true)

                ElementRectView(label: "text", level: 1, origin: .init(x: 140, y: 160), size: CGSize(width: 100, height: 30), showCollect: true)

                ElementRectView(label: "text", level: 2, origin: .init(x: 260, y: 150), size: CGSize(width: 100, height: 30), showCollect: true)

            }
            .environment(\.perspectiveInfo, perspective)
            .simultaneousGesture(
                DragGesture(minimumDistance: 0)
                    .onChanged({
                        gesture in
                        let centerX = proxy.size.width / 2
                        let centerY = proxy.size.height / 2

                        let x = 0 - (gesture.location.y / centerY - 1)
                        let y = (gesture.location.x / centerX - 1)

                        let x1 = gesture.location.x - centerX
                        let y1 = gesture.location.y - centerY

                        let range = sqrt(x1 * x1 + y1 * y1)
                        let degreesFactor = range / sqrt(2 * centerX * centerX)

                        withAnimation {
                            perspective = PerpectiveInfo(
                                degrees: Double(30 * degreesFactor.clamped(0, 1)),
                                pointX: x,
                                pointY: y
                            )
                        }
                        draging = true
                    })
                    .onEnded(onDragEndedAction(gesture:))
            )
        }

    }
    private func onDragEndedAction(gesture: DragGesture.Value) -> Void {
        withAnimation {
            perspective = PerpectiveInfo(degrees: 0, pointX: 0, pointY: 0)
        }
        draging = false
    }
}

fileprivate extension Comparable {
    func clamped(_ f: Self, _ t: Self)  ->  Self {
        var r = self
        if r < f { r = f }
        if r > t { r = t }
        return r
    }
}



#Preview {
    PerspectiveView()
}
