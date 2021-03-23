defmodule Bro do
  @doc """
  Defines the list of Erlang headers that will be imported on this module.

    use Bro, [
      {"path_to_header/header.hrl", only: [:rec1, :rec2]},
      "path_to_header2/header2.hrl",
      ...
    ]

  This will create two modules:

  - Records: Inside this umbrella module, there will be as many sub-modules as records present in all the headers. Each sub-module will define the record with `Record.defrecord`.
  - Structs: This module will contain all the Elixir module definitions as submodules, as well as the conversion functions (to_struct/1, to_record/1). The Elixir modules will be named as the camelized version of the record (e.g., the `sasl_abort` record will be mapped to the `SaslAbort` struct).
  """
  @spec __using__([Path.t() | {Path.t(), keyword()}]) :: none
  defmacro __using__(modules) do

    {all_defrecords, all_converters} =
      modules
      |> Enum.reduce(
        {[], []},
        fn filepath, {all_defrecords, all_converters} ->
          {mod_defrecords, mod_converters} = extract_header(filepath)
          {mod_defrecords ++ all_defrecords, mod_converters ++ all_converters}
        end
      )

    quote do
      defmodule Records do
        require Record
        unquote_splicing(all_defrecords)
      end

      defmodule Structs do
        require Record
        import Records

        defp struct_value(:undefined), do: nil

        defp struct_value(val) when is_list(val) do
          Enum.map(val, &struct_value/1)
        end

        defp struct_value(val) when Record.is_record(val) do
          to_struct(val) || val
        end

        defp struct_value(val), do: val

        unquote_splicing(all_converters)

        def to_record(_), do: nil
        def to_struct(_), do: nil
      end
    end
  end

  @spec extract_header(Path.t()) :: none
  defp extract_header(header) do
    {file_path, opts} =
      case header do
        {_file_path, _opts} -> header
        file_path -> {file_path, []}
      end

    only_record = opts[:only_record] || []

    extracted_records =
      case opts[:only] do
        nil ->
          Record.extract_all(from: file_path)

        only ->
          only
          |> Enum.map(&{&1, Record.extract(&1, from: file_path)})
      end

    convertible_records =
      extracted_records
      |> Enum.filter(fn {record_name, _fields} -> record_name not in only_record end)

    mod_defrecords =
      for {record_name, fields} <- extracted_records do
        quote do
          Record.defrecord(unquote(record_name), unquote(Macro.escape(fields)))
        end
      end

    mod_converters =
      for {record_name, fields} <- convertible_records do
        struct_name =
          record_name
          |> to_string()
          |> Macro.camelize()
          |> String.to_atom()
          |> (fn x -> {:__aliases__, [alias: false], [x]} end).()

        kv_struct2rec =
          for {key, _default_val} <- fields do
            {key,
             quote do
               case Map.get(struct, unquote(key)) do
                 nil -> :undefined
                 val -> val
               end
             end}
          end

        kv_rec2struct =
          for {key, _default_val} <- fields do
            {key,
             quote do
               struct_value(unquote(record_name)(record, unquote(key)))
             end}
          end

        map_fields =
          fields
          |> Macro.escape()
          |> Enum.map(fn
            {k, :undefined} -> {k, nil}
            kv -> kv
          end)

        quote do
          defmodule unquote(struct_name) do
            @moduledoc false
            defstruct unquote(map_fields)
          end

          def to_record(%unquote(struct_name){} = struct) do
            unquote(record_name)(unquote(kv_struct2rec))
          end

          def to_struct(unquote(record_name)() = record) do
            struct(unquote(struct_name), unquote(kv_rec2struct))
          end
        end
      end

    {mod_defrecords, mod_converters}
  end
end
