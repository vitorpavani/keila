defmodule Keila.Contacts.Contact do
  use Keila.Schema, prefix: "c"
  alias Keila.Contacts.Form

  @statuses Enum.with_index([
              :active,
              :unsubscribed,
              :unreachable
            ])

  schema "contacts" do
    field(:email, :string)
    field(:first_name, :string)
    field(:last_name, :string)
    field(:status, Ecto.Enum, values: @statuses, default: :active)
    field(:data, :map)
    belongs_to(:project, Keila.Projects.Project, type: Keila.Projects.Project.Id)
    timestamps()
  end

  @spec creation_changeset(t(), Ecto.Changeset.data()) :: Ecto.Changeset.t(t())
  def creation_changeset(struct \\ %__MODULE__{}, params) do
    struct
    |> cast(params, [:email, :first_name, :last_name, :project_id])
    |> put_data_field(params)
    |> validate_required([:email, :project_id])
    |> validate_format(:email, ~r/^[^\s]+@[^\s]+$/, message: "must have the @ sign and no spaces")
    |> unique_constraint([:email, :project_id])
  end

  @spec update_changeset(t(), Ecto.Changeset.data()) :: Ecto.Changeset.t(t())
  def update_changeset(struct \\ %__MODULE__{}, params) do
    struct
    |> cast(params, [:email, :first_name, :last_name])
    |> put_data_field(params)
    |> validate_required([:email])
    |> validate_format(:email, ~r/^[^\s]+@[^\s]+$/, message: "must have the @ sign and no spaces")
  end

  defp put_data_field(changeset, params) do
    if Map.has_key?(params, "data") || Map.has_key?(params, :data) do
      raw_data = Map.get(params, "data") || Map.get(params, :data)

      changeset
      |> parse_and_put_data_field(raw_data)
    else
      changeset
    end
  end

  defp parse_and_put_data_field(changeset, data) when is_map(data),
    do: put_change(changeset, :data, data)

  defp parse_and_put_data_field(changeset, data) when is_nil(data) or data == "",
    do: put_change(changeset, :data, nil)

  defp parse_and_put_data_field(changeset, data) when is_binary(data) do
    case Jason.decode(data) do
      {:ok, data} when is_map(data) ->
        put_change(changeset, :data, data)

      {:ok, _} ->
        changeset |> put_change(:data, data) |> add_error(:data, "must be a JSON object")

      {:error, error = %Jason.DecodeError{}} ->
        message = Jason.DecodeError.message(error)
        changeset |> put_change(:data, data) |> add_error(:data, message)
    end
  end

  @spec changeset_from_form(t(), Ecto.Changeset.data(), Form.t()) :: Ecto.Changeset.t(t())
  def changeset_from_form(struct \\ %__MODULE__{}, params, form) do
    cast_fields =
      form.field_settings
      |> Enum.filter(& &1.cast)
      |> Enum.map(&String.to_existing_atom(&1.field))

    required_fields =
      form.field_settings
      |> Enum.filter(&(&1.cast and &1.required))
      |> Enum.map(&String.to_existing_atom(&1.field))

    struct
    |> cast(params, cast_fields)
    |> validate_dynamic_required(required_fields)
    |> validate_required([:email])
    |> validate_format(:email, ~r/^[^\s]+@[^\s]+$/, message: "must have the @ sign and no spaces")
    |> unique_constraint([:email, :project_id])
  end

  defp validate_dynamic_required(changeset, required_fields)
  defp validate_dynamic_required(changeset, []), do: changeset
  defp validate_dynamic_required(changeset, fields), do: validate_required(changeset, fields)
end
