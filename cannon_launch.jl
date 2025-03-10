using LinearAlgebra, GLMakie, FileIO, Colors


global masa = 43.0             
global proch =12.0        
global wspl_ubicia = 0.9             
global wspolczynnik_spalania=2.8*10^5 # proch czarny 2.8MJ/kg
global kat_azymut = 0           
global g = 9.81                    
                  # krok czasowy
fps = 30                    # liczba klatek na sekundę

function symulacja_3d(vxo, vyo, vzo, g, dt, start_x, start_y, start_z)
    
    trajektoria = [(start_x, start_y, start_z)]  
    x, y, z = start_x, start_y, start_z
    vx, vy, vz = vxo, vyo, vzo
    
    while  z >= 0 
        x += vx
        y += vy 
        z += vz 
        vz -= g  

            if z <= 0
            z = 0
            push!(trajektoria, (x, y, z)) 
            break
            end
           
        push!(trajektoria, (x, y, z))
        
    end
    return trajektoria
end


function main()
  
    fig = Figure(resolution = (1500, 1000))
    ax = Axis3(fig[1:4, 1:4],
        title = "Armata",
        xlabel = "X ",
        ylabel = "Y ",
        zlabel = "Z "
    )
    hidespines!(ax)
    limits!(ax, 0, 200, -100, 100, 0, 100)

     try
        lufa_mesh = FileIO.load("c:/Users/zprzy/Desktop/wno/armata.obj")
        lufa_obj = mesh!(ax, lufa_mesh, color = :grey)
        GLMakie.translate!(lufa_obj, Vec3f(-41.0, 0.0, 3.0))  
        end_of_cannon = Observable(Vec3f(-41.0, 0.0, 0.0))  # Początkowa pozycja końca lufy

        display(fig)

       
        slider = Slider(fig[5, 1], range = 0:0.1:70, startvalue = 0)
        label = Label(fig[5, 2], text = "Kąt lufy: $(slider.value[])°")
        textbox_m = Textbox(fig[6, 1], placeholder = "Masa pocisku (kg)", width = 200)
        textbox_p = Textbox(fig[6, 2], placeholder = "Ilość prochu", width = 200)
        textbox_c = Textbox(fig[6, 3], placeholder = "Współczynnik ubicia prochu", width = 200)
        button = Button(fig[7, 1], label = "Wystrzel pocisk")

        
        on(slider.value) do kat
                label.text = "Kąt lufy: $(round(kat))°"
                kat = deg2rad(kat)
                GLMakie.rotate!(lufa_obj, Vec3f(0.0, 01.0, 0.0), -kat)

            
            cannon_length =41.0  
            end_x = -41.0 + (cannon_length * cos(kat))
            end_z = 3.0 + (cannon_length * sin(kat))
            end_of_cannon[] = Vec3f(end_x, 0.0, end_z)

           
        end

     
        function text()
            input_m = textbox_m.stored_string[]
            if input_m != nothing && !isempty(input_m) #funckcja zmodyfikowana i znaleziona na https://discourse.julialang.org/
                parsed_m = tryparse(Float64, input_m)
                if parsed_m != nothing
                    global masa = parsed_m
                end
            end
            
            input_p = textbox_p.stored_string[]
            if input_p != nothing && !isempty(input_p)
                parsed_p = tryparse(Float64, input_p)
                if parsed_p != nothing
                    global proch = parsed_p
                end
            end

            input_wspl = textbox_c.stored_string[]
            if input_wspl != nothing && !isempty(input_wspl)
                parsed_wspl= tryparse(Float64, input_wspl)
                if parsed_wspl != nothing
                    global wspl_ubicia = parsed_wspl
                end
            end
          
            println("Zaktualizowane parametry: masa = $masa kg, ilość prochu = $proch, współczynnik ubicia = $wspl_ubicia")
        end
  
        
        on(button.clicks) do _
            text()
            initial = ax.limits[]
            @async begin
                try
                 
                    # Wybuch armaty
                        kat = deg2rad(slider.value[])
                        println(masa, proch, wspl_ubicia)
                        ek = sila_wybuchu = wspl_ubicia * wspolczynnik_spalania * proch         #wikipedia plus chatgpt
                        vo = sqrt(2 * ek / masa)
                        vxo = vo * cos(kat) * cos(kat_azymut)
                        vyo = vo * cos(kat) * sin(kat_azymut)
                        vzo = vo * sin(kat)
                        num_particles = Int(round(proch * wspl_ubicia*10))
        
                    
                        start_position = end_of_cannon[]
                        trajektoria = symulacja_3d(vxo, vyo, vzo, g, dt, start_position[1], start_position[2], start_position[3])


                        colors = Observable([RGBA(0.5, 0.5, 0.5, 1.0) for _ in 1:num_particles]) # rgb z pomoca chatgpt
                        particles = Observable([Point3f(start_position) for _ in 1:num_particles])
                        scatter!(ax, particles, markersize =10, color = colors)

        
                        animation = length(trajektoria)
                        current_point = Observable(Point3f(start_position))
                        pocisk_obj = scatter!(ax, current_point, color = :black, markersize = 10)
                        # Wybuch
                    explosion_radius = sqrt(sila_wybuchu) /50
                    explosion_duration = animation/5 
      
        for t in 1:animation
            
            x, y, z = trajektoria[t]
            current_point[] = Point3f(x, y, z)
            new_position = Point3f(x, y, z)
            
            
            current_point[] = new_position
            
            
            current_limits = ax.limits[]
            ax.limits[] = (
                (min(current_limits[1][1], new_position[1]), max(current_limits[1][2], new_position[1] + 100)),  
                (min(current_limits[2][1], new_position[2]), max(current_limits[2][2], new_position[2] + 100)),  #chatgpt
                (min(current_limits[3][1], new_position[3]), max(current_limits[3][2], new_position[3] + 50))   
            )
            
            if t <= explosion_duration
                new_positions = [Point3f(
                    x + (rand() - 0.5) * explosion_radius * cos(kat)*sin(deg2rad(30)),  
                    y + (rand() - 0.5) * explosion_radius*sin(kat)*cos(deg2rad(30)),            #chatgpt          
                    z - (rand() - 0.5) * explosion_radius *cos(kat)             
                ) for _ in 1:num_particles]
        
        
                particles[] = new_positions
                notify(particles)
        
                
               
                if t > explosion_duration * 0.7
                    new_colors = [RGBA(1.0, 0.0, 0.0, 1.0) for _ in 1:num_particles]  # Czerwony kolor
                    colors[] = new_colors
                    notify(colors)
                    end
                    elseif t > explosion_duration
                
                         particles[] = []
                        notify(particles)
        
                    end
                    sleep(1 / fps)
                    particles[] = []
                 end
                    sleep(0.3)
                    ax.limits[]=  initial
                    final_position = trajektoria[end]
                    max_distance = sqrt(final_position[1]^2 + final_position[3]^2)
                    println("Maksymalna odległość pozioma (zasięg): $max_distance m")
                    
                   

                catch err
                    
                end
            end
        end

    catch e
        println(" $e")
    end
end

# Uruchomienie funkcji
main()
