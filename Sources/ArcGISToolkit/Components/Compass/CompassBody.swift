// Copyright 2022 Esri
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//   https://www.apache.org/licenses/LICENSE-2.0
//
// Unless required by applicable law or agreed to in writing, software
// distributed under the License is distributed on an "AS IS" BASIS,
// WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
// See the License for the specific language governing permissions and
// limitations under the License.

import SwiftUI

/// Represents the circular housing which encompasses the spinning needle at the center of the compass.
struct CompassBody: View {
    // Note: Bastian changed this to reflect the ETH design
    
    var body: some View {
        Color.clear
            .background {
                Circle()
                    .fill(Color(uiColor: UIColor { $0.userInterfaceStyle == .dark ? .black : .white }))
            }
            .clipped()
            .shadow(radius: 4)
    }
}
