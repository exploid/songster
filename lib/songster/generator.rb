module Songster

  class Generator

    def initialize(image_path)
      @image_path = image_path
    end

    def generate!
      face = Songster::Face.new(@image_path).detect!

      @dir = Dir.mktmpdir("songster")

      puts "Putting temporary files in #{@dir}".green if Songster.debug

      convert_original_to_gif

      create_mouth_top_crop(face.mouth)
      create_mouth_bottom_crop(face.mouth)
      merge_top_and_bottom_of_mouth

      merge_opened_mouth_and_original(face.mouth)

      animate_into_gif

      # @todo Cleanup the tmp directory
    end # generate!

    private

    def convert_original_to_gif
      Commander.new("convert", @image_path,
                    "-format miff #{@dir}/giffed.miff").run!
    end

    # Create a crop of the mouth upper lip with black padding on the bottom
    def create_mouth_top_crop(mouth)
      crop_size = "#{mouth.width}x#{mouth.height}"
      crop_location = "+#{mouth.left_x}+#{mouth.top}"

      Commander.new("convert #{@dir}/giffed.miff",

                    # Fill the section below the mouth's left side in black.
                    "-fill black -stroke black -draw \"polygon",
                    "  #{mouth.left_x},#{mouth.left_y}",
                    "  #{mouth.center_x},#{mouth.center_y}",
                    "  #{mouth.left_x},#{mouth.bottom}",
                    "\"",

                    # Fill the section below the mouth's right side in black.
                    "-fill black -stroke black -draw \"polygon",
                    "  #{mouth.right_x},#{mouth.right_y}",
                    "  #{mouth.center_x},#{mouth.center_y}",
                    "  #{mouth.right_x},#{mouth.bottom}",
                    "\"",

                    "-crop #{crop_size}#{crop_location}",

                    "#{@dir}/top.miff").run!
    end

    # Create a crop of the mouth bottom lip with black padding on the top
    def create_mouth_bottom_crop(mouth)
      crop_size = "#{mouth.width}x#{mouth.chin_height+mouth.opening_size}"
      crop_location = "+#{mouth.left_x}+#{mouth.middle}"

      Commander.new("convert #{@dir}/giffed.miff",

                    "-fill black -stroke black",
                    "-draw \"path '",
                    "    M #{mouth.left_x},#{mouth.left_y}",
                    "    C #{mouth.center_x},#{mouth.center_y+5}",
                    "      #{mouth.center_x},#{mouth.center_y+5}",
                    "      #{mouth.right_x},#{mouth.right_y}'",
                    "\"",

                    # Add black padding to adjust how big the mouth opens.
                    "-gravity northwest -background black",
                    "-splice 0x#{mouth.opening_size}+0+#{mouth.middle}",

                    # Crop to get the results.
                    "-crop #{crop_size}#{crop_location}",

                    "#{@dir}/bottom.miff").run!
    end

    # Merge the top and bottom part of the mouth to create the opened mouth.
    def merge_top_and_bottom_of_mouth
      Commander.new("convert #{@dir}/top.miff #{@dir}/bottom.miff",
                    "-append #{@dir}/opened_mouth.miff").run!
    end

    # Put the opened mouth over the original image.
    def merge_opened_mouth_and_original(mouth)
      Commander.new("composite #{@dir}/opened_mouth.miff #{@dir}/giffed.miff",
                    "-gravity northwest -geometry +#{mouth.x}+#{mouth.y}",
                    "#{@dir}/offset_mouth.miff").run!
    end

    # Build a gif of the original image and the image with opened mouths
    def animate_into_gif
      fname = Pathname.new(@image_path).basename.sub_ext("")

      animate = Commander.new("convert -loop 0 -delay 30")
      animate << "#{@dir}/giffed.miff #{@dir}/offset_mouth.miff"
      animate << "images/#{fname}-singing.gif"
      animate.run!
    end

  end # Generator
end # Songster
