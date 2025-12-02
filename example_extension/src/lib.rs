use godot::classes::{ISprite2D, Input, Sprite2D};
use godot::prelude::*;

use crate::project_constants::autoloads::{global_rust_autoload, renamed_rust_autoload};
use crate::project_constants::input_actions::UI_ACCEPT;
mod project_constants;

struct ExampleExtension;

#[gdextension]
unsafe impl ExtensionLibrary for ExampleExtension {}

#[derive(GodotClass)]
#[class(init, base = Node)]
pub struct RustAutoload {}

#[derive(GodotClass)]
#[class(init, base = Node, rename = RenamedAutoload)]
pub struct RenamedRustAutoload {}

/// A sprite that spins around its origin at a fixed speed.
#[derive(GodotClass)]
#[class(init, base = Sprite2D)]
struct Spinning {
    /// The speed at which the sprite spins, in radians per second.
    #[export]
    angular_speed: f32,

    base: Base<Sprite2D>,
}

#[godot_api]
impl ISprite2D for Spinning {
    fn ready(&mut self) {
        godot_print!(
            "Accessing both autoloads: {}, {}",
            global_rust_autoload(),
            renamed_rust_autoload()
        );
    }

    fn physics_process(&mut self, delta: f32) {
        if Input::singleton().is_action_just_pressed(UI_ACCEPT) {
            godot_print!("Hello world!");
        }
        let angle_delta = self.angular_speed * delta;
        self.base_mut().rotate(angle_delta);
    }
}
