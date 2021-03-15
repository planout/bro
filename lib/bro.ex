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
    {allDefrecords, allConverters} =
      modules
      |> Enum.reduce(
        {[], []},
        fn filepath, {allDefrecords, allConverters} ->
          {modDefrecords, modConverters} = extractHeader(filepath)
          {modDefrecords ++ allDefrecords, modConverters ++ allConverters}
        end
      )

    quote do
      defmodule Records do
        require Record
        unquote_splicing(allDefrecords)
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

        unquote_splicing(allConverters)

        def to_record(_), do: nil
        def to_struct(_), do: nil
      end
    end
  end

  @spec extractHeader(Path.t()) :: none
  defp extractHeader(header) do
    extractedRecords =
      case header do
        {filePath, [only: only]} ->
          only
          |> Enum.map(& {&1, Record.extract(&1, from: filePath)})
        filePath ->
          Record.extract_all(from: filePath)
      end

    modDefrecords =
      for {recordName, fields} <- extractedRecords do
        quote do
          Record.defrecord(unquote(recordName), unquote(Macro.escape(fields)))
        end
      end

    modConverters =
      for {recordName, fields} <- extractedRecords do
        structName =
          recordName
          |> to_string()
          |> Macro.camelize()
          |> String.to_atom()
          |> (fn x -> {:__aliases__, [alias: false], [x]} end).()

        kv_struct2rec =
          for {key, _defaultVal} <- fields do
            {key,
             quote do
               case Map.get(struct, unquote(key)) do
                 nil -> :undefined
                 val -> val
               end
             end}
          end

        kv_rec2struct =
          for {key, _defaultVal} <- fields do
            {key,
             quote do
               struct_value(unquote(recordName)(record, unquote(key)))
             end}
          end

        mapFields =
          fields
          |> Macro.escape()
          |> Enum.map(fn
            {k, :undefined} -> {k, nil}
            kv -> kv
          end)

        quote do
          defmodule unquote(structName) do
            @moduledoc false
            defstruct unquote(mapFields)
          end

          def to_record(%unquote(structName){} = struct) do
            unquote(recordName)(unquote(kv_struct2rec))
          end

          def to_struct(unquote(recordName)() = record) do
            struct(unquote(structName), unquote(kv_rec2struct))
          end
        end
      end

    {modDefrecords, modConverters}
  end
end
