defmodule ElixirSense.Providers.DefinitionTest do
  use ExUnit.Case, async: true
  alias ElixirSense.Providers.Definition
  alias ElixirSense.Providers.Definition.Location

  doctest Definition

  test "find definition of aliased modules in `use`" do
    buffer = """
    defmodule MyModule do
      alias ElixirSenseExample.UseExample
      use UseExample
      #        ^
    end
    """

    %{found: true, type: :module, file: file, line: line, column: column} =
      ElixirSense.definition(buffer, 3, 12)

    assert file =~ "elixir_sense/test/support/use_example.ex"
    assert read_line(file, {line, column}) =~ "ElixirSenseExample.UseExample"
  end

  @tag requires_source: true
  test "find definition of functions from Kernel" do
    buffer = """
    defmodule MyModule do
    #^
    end
    """

    %{found: true, type: :function, file: file, line: line, column: column} =
      ElixirSense.definition(buffer, 1, 2)

    assert file =~ "lib/elixir/lib/kernel.ex"
    assert read_line(file, {line, column}) =~ "defmodule("
  end

  @tag requires_source: true
  test "find definition of functions from Kernel.SpecialForms" do
    buffer = """
    defmodule MyModule do
      import List
       ^
    end
    """

    %{found: true, type: :function, file: file, line: line, column: column} =
      ElixirSense.definition(buffer, 2, 4)

    assert file =~ "lib/elixir/lib/kernel/special_forms.ex"
    assert read_line(file, {line, column}) =~ "import"
  end

  test "find definition of functions from imports" do
    buffer = """
    defmodule MyModule do
      import ElixirSenseExample.ModuleWithFunctions
      function_arity_zero()
      #^
    end
    """

    %{found: true, type: :function, file: file, line: line, column: column} =
      ElixirSense.definition(buffer, 3, 4)

    assert file =~ "elixir_sense/test/support/module_with_functions.ex"
    assert read_line(file, {line, column}) =~ "function_arity_zero"
  end

  test "find definition of functions from aliased modules" do
    buffer = """
    defmodule MyModule do
      alias ElixirSenseExample.ModuleWithFunctions, as: MyMod
      MyMod.function_arity_one(42)
      #        ^
    end
    """

    %{found: true, type: :function, file: file, line: line, column: column} =
      ElixirSense.definition(buffer, 3, 11)

    assert file =~ "elixir_sense/test/support/module_with_functions.ex"
    assert read_line(file, {line, column}) =~ "function_arity_one"
  end

  test "find definition of functions piped from aliased modules" do
    buffer = """
    defmodule MyModule do
      alias ElixirSenseExample.ModuleWithFunctions, as: MyMod
      42 |> MyMod.function_arity_one()
      #              ^
    end
    """

    %{found: true, type: :function, file: file, line: line, column: column} =
      ElixirSense.definition(buffer, 3, 17)

    assert file =~ "elixir_sense/test/support/module_with_functions.ex"
    assert read_line(file, {line, column}) =~ "function_arity_one"
  end

  test "find definition of functions captured from aliased modules" do
    buffer = """
    defmodule MyModule do
      alias ElixirSenseExample.ModuleWithFunctions, as: MyMod
      &MyMod.function_arity_one/1
      #              ^
    end
    """

    %{found: true, type: :function, file: file, line: line, column: column} =
      ElixirSense.definition(buffer, 3, 17)

    assert file =~ "elixir_sense/test/support/module_with_functions.ex"
    assert read_line(file, {line, column}) =~ "function_arity_one"
  end

  test "find definition of delegated functions" do
    buffer = """
    defmodule MyModule do
      alias ElixirSenseExample.ModuleWithFunctions, as: MyMod
      MyMod.delegated_function()
      #        ^
    end
    """

    %{found: true, type: :function, file: file, line: line, column: column} =
      ElixirSense.definition(buffer, 3, 11)

    assert file =~ "elixir_sense/test/support/module_with_functions.ex"
    assert read_line(file, {line, column}) =~ "delegated_function"
  end

  test "find definition of modules" do
    buffer = """
    defmodule MyModule do
      alias List, as: MyList
      ElixirSenseExample.ModuleWithFunctions.function_arity_zero()
      #                   ^
    end
    """

    %{found: true, type: :module, file: file, line: line, column: column} =
      ElixirSense.definition(buffer, 3, 23)

    assert file =~ "elixir_sense/test/support/module_with_functions.ex"
    assert read_line(file, {line, column}) =~ "ElixirSenseExample.ModuleWithFunctions do"
  end

  test "find definition of erlang modules" do
    buffer = """
    defmodule MyModule do
      def dup(x) do
        :lists.duplicate(2, x)
        # ^
      end
    end
    """

    %Location{found: true, type: :module, file: file, line: 1, column: 1} =
      ElixirSense.definition(buffer, 3, 7)

    assert file =~ "/src/lists.erl"
  end

  test "find definition of remote erlang functions" do
    buffer = """
    defmodule MyModule do
      def dup(x) do
        :lists.duplicate(2, x)
        #         ^
      end
    end
    """

    %{found: true, type: :function, file: file, line: line, column: column} =
      ElixirSense.definition(buffer, 3, 15)

    assert file =~ "/src/lists.erl"
    assert read_line(file, {line, column}) =~ "duplicate(N, X)"
  end

  test "find definition of remote erlang functions from preloaded module" do
    buffer = """
    defmodule MyModule do
      def dup(x) do
        :erlang.start_timer(2, x, 4)
        #         ^
      end
    end
    """

    %{found: true, type: :function, file: file, line: line, column: column} =
      ElixirSense.definition(buffer, 3, 15)

    assert file =~ "/src/erlang.erl"
    assert read_line(file, {line, column}) =~ "start_timer(_Time, _Dest, _Msg)"
  end

  test "non existing modules" do
    buffer = """
    defmodule MyModule do
      SilverBulletModule.run
    end
    """

    assert ElixirSense.definition(buffer, 2, 24) == %Location{found: false}
  end

  test "cannot find map field calls" do
    buffer = """
    defmodule MyModule do
      env = __ENV__
      IO.puts(env.file)
      #            ^
    end
    """

    assert ElixirSense.definition(buffer, 3, 16) == %Location{found: false}
  end

  test "cannot find map fields" do
    buffer = """
    defmodule MyModule do
      var = %{count: 1}
      #        ^
    end
    """

    assert ElixirSense.definition(buffer, 2, 12) == %Location{found: false}
  end

  test "preloaded modules" do
    buffer = """
    defmodule MyModule do
      :erlang.node
      # ^
    end
    """

    assert %Location{found: true, line: 1, column: 1, type: :module, file: file} =
             ElixirSense.definition(buffer, 2, 5)

    assert file =~ "/src/erlang.erl"
  end

  test "cannot find built-in functions" do
    # module_info is defined by default for every elixir and erlang module:
    # https://stackoverflow.com/a/33373107/175830
    buffer = """
    defmodule MyModule do
      ElixirSenseExample.ModuleWithFunctions.module_info()
      #                                      ^
    end
    """

    assert %{found: false} = ElixirSense.definition(buffer, 2, 42)
  end

  test "find definition of variables" do
    buffer = """
    defmodule MyModule do
      def func do
        var1 = 1
        var2 = 2
        var1 = 3
        IO.puts(var1 + var2)
      end
    end
    """

    assert ElixirSense.definition(buffer, 6, 13) == %Location{
             found: true,
             type: :variable,
             file: nil,
             line: 3,
             column: 5
           }

    assert ElixirSense.definition(buffer, 6, 21) == %Location{
             found: true,
             type: :variable,
             file: nil,
             line: 4,
             column: 5
           }
  end

  test "find definition of functions when name not same as variable" do
    buffer = """
    defmodule MyModule do
      def my_fun(), do: :ok

      def a do
        my_fun1 = 1
        my_fun()
      end
    end
    """

    assert ElixirSense.definition(buffer, 6, 6) == %Location{
             found: true,
             type: :function,
             file: nil,
             line: 2,
             column: 7
           }
  end

  test "find definition of functions when name same as variable" do
    buffer = """
    defmodule MyModule do
      def my_fun(), do: :ok

      def a do
        my_fun = 1
        my_fun()
      end
    end
    """

    assert ElixirSense.definition(buffer, 6, 6) == %Location{
             found: true,
             type: :function,
             file: nil,
             line: 2,
             column: 7
           }
  end

  test "find definition of variables when name same as function" do
    buffer = """
    defmodule MyModule do
      def my_fun(), do: :error

      def a do
        my_fun = fn -> :ok end
        my_fun.()
      end
    end
    """

    assert ElixirSense.definition(buffer, 6, 6) == %Location{
             found: true,
             type: :variable,
             file: nil,
             line: 5,
             column: 5
           }
  end

  test "find definition of local functions with __MODULE__" do
    buffer = """
    defmodule MyModule do
      def my_fun(), do: :ok

      def a do
        my_fun1 = 1
        __MODULE__.my_fun()
      end
    end
    """

    assert ElixirSense.definition(buffer, 6, 17) == %Location{
             found: true,
             type: :function,
             file: nil,
             line: 2,
             column: 7
           }
  end

  test "find definition of local functions with current module" do
    buffer = """
    defmodule MyModule do
      def my_fun(), do: :ok

      def a do
        my_fun1 = 1
        MyModule.my_fun()
      end
    end
    """

    assert ElixirSense.definition(buffer, 6, 14) == %Location{
             found: true,
             type: :function,
             file: nil,
             line: 2,
             column: 7
           }
  end

  test "find definition of local functions with atom module" do
    buffer = """
    defmodule MyModule do
      def my_fun(), do: :ok

      def a do
        my_fun1 = 1
        :"Elixir.MyModule".my_fun()
      end
    end
    """

    assert ElixirSense.definition(buffer, 6, 24) == %Location{
             found: true,
             type: :function,
             file: nil,
             line: 2,
             column: 7
           }
  end

  test "find definition of local functions with alias" do
    buffer = """
    defmodule MyModule do
      alias MyModule, as: M
      def my_fun(), do: :ok

      def a do
        my_fun1 = 1
        M.my_fun()
      end
    end
    """

    assert ElixirSense.definition(buffer, 7, 7) == %Location{
             found: true,
             type: :function,
             file: nil,
             line: 3,
             column: 7
           }
  end

  test "find definition of local module" do
    buffer = """
    defmodule MyModule do
      defmodule Submodule do
        def my_fun(), do: :ok
      end

      def a do
        MyModule.Submodule.my_fun()
      end
    end
    """

    assert ElixirSense.definition(buffer, 7, 16) == %Location{
             found: true,
             type: :module,
             file: nil,
             line: 2,
             column: 13
           }
  end

  test "find definition of params" do
    buffer = """
    defmodule MyModule do
      def func(%{a: [var2|_]}) do
        var1 = 3
        IO.puts(var1 + var2)
        #               ^
      end
    end
    """

    assert ElixirSense.definition(buffer, 4, 21) == %ElixirSense.Providers.Definition.Location{
             found: true,
             type: :variable,
             file: nil,
             line: 2,
             column: 18
           }
  end

  test "find local type definition" do
    buffer = """
    defmodule ElixirSenseExample.ModuleWithTypespecs.Remote do
      @type remote_list_t :: [remote_t]
      #                           ^
    end
    """

    %{found: true, type: :typespec, file: file, line: line, column: column} =
      ElixirSense.definition(buffer, 2, 31)

    assert file =~ "elixir_sense/test/support/module_with_typespecs.ex"
    assert read_line(file, {line, column}) =~ ~r/^remote_t ::/
  end

  test "find remote type definition" do
    buffer = """
    defmodule MyModule do
      alias ElixirSenseExample.ModuleWithTypespecs.Remote
      Remote.remote_t
      #         ^
    end
    """

    %{found: true, type: :typespec, file: file, line: line, column: column} =
      ElixirSense.definition(buffer, 3, 13)

    assert file =~ "elixir_sense/test/support/module_with_typespecs.ex"
    assert read_line(file, {line, column}) =~ ~r/^remote_t ::/
  end

  test "find type definition without @typedoc" do
    buffer = """
    defmodule MyModule do
      alias ElixirSenseExample.ModuleWithTypespecs.Remote
      Remote.remote_option_t
      #         ^
    end
    """

    %{found: true, type: :typespec, file: file, line: line, column: column} =
      ElixirSense.definition(buffer, 3, 13)

    assert file =~ "elixir_sense/test/support/module_with_typespecs.ex"
    assert read_line(file, {line, column}) =~ ~r/^remote_option_t ::/
  end

  test "find opaque type definition" do
    buffer = """
    defmodule MyModule do
      alias ElixirSenseExample.ModuleWithTypespecs.Local
      Local.opaque_t
      #        ^
    end
    """

    %{found: true, type: :typespec, file: file, line: line, column: column} =
      ElixirSense.definition(buffer, 3, 12)

    assert file =~ "elixir_sense/test/support/module_with_typespecs.ex"
    assert read_line(file, {line, column}) =~ ~r/^opaque_t ::/
  end

  test "find erlang type definition" do
    buffer = """
    defmodule MyModule do
      :ets.tab
      #     ^
    end
    """

    %{found: true, type: :typespec, file: file, line: line, column: column} =
      ElixirSense.definition(buffer, 2, 9)

    assert file =~ "/src/ets.erl"
    assert read_line(file, {line, column}) =~ "-type tab()"
  end

  test "find erlang type definition from preloaded module" do
    buffer = """
    defmodule MyModule do
      :erlang.time_unit
      #        ^
    end
    """

    %{found: true, type: :typespec, file: file, line: line, column: column} =
      ElixirSense.definition(buffer, 2, 12)

    assert file =~ "/src/erlang.erl"
    assert read_line(file, {line, column}) =~ "-type time_unit()"
  end

  test "builtin types cannot now be found" do
    buffer = """
    defmodule MyModule do
      @type my_type :: integer
      #                   ^
    end
    """

    assert %{found: false} = ElixirSense.definition(buffer, 2, 23)
  end

  test "find local metadata type definition" do
    buffer = """
    defmodule MyModule do
      @typep my_t :: integer

      @type remote_list_t :: [my_t]
      #                         ^
    end
    """

    %{found: true, type: :typespec, file: nil, line: 2, column: 3} =
      ElixirSense.definition(buffer, 4, 29)
  end

  test "find remote metadata type definition" do
    buffer = """
    defmodule MyModule.Other do
      @type my_t :: integer
    end

    defmodule MyModule do
      alias MyModule.Other

      @type remote_list_t :: [Other.my_t]
      #                               ^
    end
    """

    %{found: true, type: :typespec, file: nil, line: 2, column: 3} =
      ElixirSense.definition(buffer, 8, 35)
  end

  defp read_line(file, {line, column}) do
    file
    |> File.read!()
    |> String.split(["\n", "\r\n"])
    |> Enum.at(line - 1)
    |> String.slice((column - 1)..-1)
  end
end
