//
//  ContentView.swift
//  Shared
//
//  Created by Morten Bertz on 2021/05/19.
//

import SwiftUI

struct ContentView: View {
    @StateObject var generator=SignalGenerator()
    @State var showLowRange:Bool = false
    
    @State var numberOfFrequencies:Int=1
    
    var body: some View {
        VStack{
            picker
            VStack{
                Slider(value: $generator.amplitude, in: Float(0)...1, minimumValueLabel: Image(systemName:"speaker.wave.1"), maximumValueLabel: Image(systemName:"speaker.wave.3")){
                    Text("")
                }
                
                Text("Volume: \(generator.amplitude, specifier: "%.2f")")
            }
            ScrollView{
                
                ForEach(Array(zip(generator.nodes, generator.nodes.indices)), id: \.0.id, content: {(node,idx) in
                    if idx > 0{
                        FrequencySliderView(node: node, showClose: true, removeHandler:{node in
                            generator.remove(node: node)
                        })
                    }
                    else{
                        FrequencySliderView(node: node, showClose: false, removeHandler: {_ in})
                    }
                    
                })
            }
            
            Spacer()
        }
        .disabled(generator.isRunning == false)
        .padding([.top, .leading, .trailing])
        .frame(minWidth: /*@START_MENU_TOKEN@*/0/*@END_MENU_TOKEN@*/, idealWidth: /*@START_MENU_TOKEN@*/100/*@END_MENU_TOKEN@*/, maxWidth: 400, minHeight: /*@START_MENU_TOKEN@*/0/*@END_MENU_TOKEN@*/, idealHeight: /*@START_MENU_TOKEN@*/100/*@END_MENU_TOKEN@*/, maxHeight: /*@START_MENU_TOKEN@*/.infinity/*@END_MENU_TOKEN@*/, alignment: /*@START_MENU_TOKEN@*/.center/*@END_MENU_TOKEN@*/)
        
        .onAppear{
            
        }
        
        .toolbar(content: {
            ToolbarItem(placement: .navigationBarTrailing, content: {
                Button(action: {
                    generator.attachNode()
                }, label: {
                    Image(systemName: "plus")
                }).disabled(!generator.isRunning || !generator.canAttachNodes)
            })
            
            ToolbarItem(placement: .navigationBarTrailing, content: {
                Button(action: {
                    generator.isRunning.toggle()
                }, label: {
                    if generator.isRunning{
                        Image(systemName: "pause")
                    }
                    else{
                        Image(systemName: "play")
                    }
                    
                })
            })
            
            
            
        })
    }
    
    
    
    var picker: some View{
        let p=Picker(selection:$generator.waveForm, label: Text("Output"), content: {
            Text(SignalGenerator.WaveForm.sine.description).tag(SignalGenerator.WaveForm.sine)
            Text(SignalGenerator.WaveForm.triangle.description).tag(SignalGenerator.WaveForm.triangle)
            Text(SignalGenerator.WaveForm.square.description).tag(SignalGenerator.WaveForm.square)
        })

        return p.pickerStyle(SegmentedPickerStyle()).fixedSize()
    }
    
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
    }
}
