defmodule Bro do
  defmacro defheaders([do: expr]) do
    quote do
      require Record

      unquote(expr)

      def from_record(xs) when is_list(xs), do: Enum.map(xs, &from_record/1)
      def from_record(:undefined), do: nil
      def from_record(x), do: x

      def to_record(xs) when is_list(xs), do: Enum.map(xs, &to_record/1)
      def to_record(nil), do: :undefined
      def to_record(x), do: x
    end
  end

  @spec defheader(Path.t(), list()) :: none
  defmacro defheader(header, opts \\ []) do
    converters = opts[:converters] || nil

    extracted_records =
      case opts[:records] do
        nil ->
          Record.extract_all(from: header)

        only ->
          only
          |> Enum.map(&{&1, Record.extract(&1, from: header)})
      end

    for {record_name, _fields} = record <- extracted_records do
      quote do
        defrec(unquote(record),
          unquote(converters == nil || record_name in converters))
      end
    end
  end

  defp nonclashing_var(key) do
    Macro.var(String.to_atom("_" <> Atom.to_string(key)), __MODULE__)
  end

  defmacro defrec({record_name, fields}, converters) do
    module_name =
      record_name
      |> to_string()
      |> Macro.camelize()
      |> String.to_atom()
      |> (fn x -> {:__aliases__, [alias: false], [x]} end).()

    field_vars =
      for {key, _default_val} <- fields do
        {key, nonclashing_var(key)}
      end

    {kv_struct2rec, kv_rec2struct} =
      for {key, var} <- field_vars do
        {
          quote do
            to_record(unquote(var))
          end,
          {key,
            quote do
              from_record(unquote(var))
            end}
        }
      end
      |> Enum.unzip()

    map_fields =
      fields
      |> Macro.escape()
      |> Enum.map(fn
        {k, :undefined} -> {k, nil}
        kv -> kv
      end)

    {defstruct_code, converters_code} =
      if converters do
        {
          quote do
            defstruct unquote(map_fields)
          end,
        quote do
          def from_record({unquote(record_name), unquote_splicing(Keyword.values(field_vars))}) do
            struct(unquote(module_name), unquote(kv_rec2struct))
          end

          def to_record(%unquote(module_name){unquote_splicing(field_vars)}) do
            {unquote(record_name), unquote_splicing(kv_struct2rec)}
          end
        end
        }
        else
        {quote do end, quote do end}
      end

    quote do
      defmodule unquote(module_name) do
        @moduledoc false
        Record.defrecord(unquote(record_name), unquote(Macro.escape(fields)))
        unquote(defstruct_code)
      end

      unquote(converters_code)
    end
  end
end
