#pragma once

#include <godot_cpp/classes/control.hpp>
#include <godot_cpp/variant/utility_functions.hpp>

using namespace godot;


class Video : public Resource {
	GDCLASS(Video, Resource);

public:
    inline void print_something(String text)
    {
        UtilityFunctions::print_rich(String("[b]Text[/b]: {text}").replace("{text}", text));
    }

protected:
	static inline void _bind_methods() {
        ClassDB::bind_method(D_METHOD("print_something", "text"), &Video::print_something);
    }

};