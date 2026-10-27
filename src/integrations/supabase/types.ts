export type Json = string | number | boolean | null | { [key: string]: Json | undefined } | Json[];

export type Database = {
  // Allows to automatically instantiate createClient with right options
  // instead of createClient<Database, { PostgrestVersion: 'XX' }>(URL, KEY)
  __InternalSupabase: {
    PostgrestVersion: "14.18";
  };
  public: {
    Tables: {
      appointments: {
        Row: {
          appointment_date: string;
          appointment_id: number;
          appointment_time: string;
          created_at: string;
          doctor_id: number;
          patient_id: number;
          status: Database["public"]["Enums"]["appointment_status"];
          updated_at: string;
        };
        Insert: {
          appointment_date: string;
          appointment_id?: never;
          appointment_time: string;
          created_at?: string;
          doctor_id: number;
          patient_id: number;
          status?: Database["public"]["Enums"]["appointment_status"];
          updated_at?: string;
        };
        Update: {
          appointment_date?: string;
          appointment_id?: never;
          appointment_time?: string;
          created_at?: string;
          doctor_id?: number;
          patient_id?: number;
          status?: Database["public"]["Enums"]["appointment_status"];
          updated_at?: string;
        };
        Relationships: [
          {
            foreignKeyName: "appointments_doctor_id_fkey";
            columns: ["doctor_id"];
            isOneToOne: false;
            referencedRelation: "doctors";
            referencedColumns: ["doctor_id"];
          },
          {
            foreignKeyName: "appointments_patient_id_fkey";
            columns: ["patient_id"];
            isOneToOne: false;
            referencedRelation: "patients";
            referencedColumns: ["patient_id"];
          },
        ];
      };
      consultations: {
        Row: {
          appointment_id: number | null;
          consultation_date: string;
          consultation_id: number;
          created_at: string;
          doctor_id: number;
          notes: string;
          patient_id: number;
          prescription: string;
          queue_id: number;
          status: Database["public"]["Enums"]["consultation_status"];
          updated_at: string;
          verified_at: string | null;
          verified_by: number | null;
        };
        Insert: {
          appointment_id?: number | null;
          consultation_date?: string;
          consultation_id?: never;
          created_at?: string;
          doctor_id: number;
          notes?: string;
          patient_id: number;
          prescription?: string;
          queue_id: number;
          status?: Database["public"]["Enums"]["consultation_status"];
          updated_at?: string;
          verified_at?: string | null;
          verified_by?: number | null;
        };
        Update: {
          appointment_id?: number | null;
          consultation_date?: string;
          consultation_id?: never;
          created_at?: string;
          doctor_id?: number;
          notes?: string;
          patient_id?: number;
          prescription?: string;
          queue_id?: number;
          status?: Database["public"]["Enums"]["consultation_status"];
          updated_at?: string;
          verified_at?: string | null;
          verified_by?: number | null;
        };
        Relationships: [
          {
            foreignKeyName: "consultations_appointment_id_fkey";
            columns: ["appointment_id"];
            isOneToOne: true;
            referencedRelation: "appointments";
            referencedColumns: ["appointment_id"];
          },
          {
            foreignKeyName: "consultations_doctor_id_fkey";
            columns: ["doctor_id"];
            isOneToOne: false;
            referencedRelation: "doctors";
            referencedColumns: ["doctor_id"];
          },
          {
            foreignKeyName: "consultations_patient_id_fkey";
            columns: ["patient_id"];
            isOneToOne: false;
            referencedRelation: "patients";
            referencedColumns: ["patient_id"];
          },
          {
            foreignKeyName: "consultations_queue_id_fkey";
            columns: ["queue_id"];
            isOneToOne: true;
            referencedRelation: "queue_entries";
            referencedColumns: ["queue_id"];
          },
          {
            foreignKeyName: "consultations_verified_by_fkey";
            columns: ["verified_by"];
            isOneToOne: false;
            referencedRelation: "receptionists";
            referencedColumns: ["receptionist_id"];
          },
        ];
      };
      doctor_availability: {
        Row: {
          availability_id: number;
          day_of_week: number;
          doctor_id: number;
          end_time: string;
          start_time: string;
        };
        Insert: {
          availability_id?: never;
          day_of_week: number;
          doctor_id: number;
          end_time: string;
          start_time: string;
        };
        Update: {
          availability_id?: never;
          day_of_week?: number;
          doctor_id?: number;
          end_time?: string;
          start_time?: string;
        };
        Relationships: [
          {
            foreignKeyName: "doctor_availability_doctor_id_fkey";
            columns: ["doctor_id"];
            isOneToOne: false;
            referencedRelation: "doctors";
            referencedColumns: ["doctor_id"];
          },
        ];
      };
      doctors: {
        Row: {
          created_at: string;
          doctor_id: number;
          name: string;
          slot_minutes: number;
          specialization: string;
          updated_at: string;
          user_id: string;
        };
        Insert: {
          created_at?: string;
          doctor_id?: never;
          name: string;
          slot_minutes?: number;
          specialization: string;
          updated_at?: string;
          user_id: string;
        };
        Update: {
          created_at?: string;
          doctor_id?: never;
          name?: string;
          slot_minutes?: number;
          specialization?: string;
          updated_at?: string;
          user_id?: string;
        };
        Relationships: [];
      };
      patients: {
        Row: {
          created_at: string;
          email: string | null;
          name: string;
          patient_id: number;
          phone: string;
          updated_at: string;
          user_id: string | null;
        };
        Insert: {
          created_at?: string;
          email?: string | null;
          name: string;
          patient_id?: never;
          phone: string;
          updated_at?: string;
          user_id?: string | null;
        };
        Update: {
          created_at?: string;
          email?: string | null;
          name?: string;
          patient_id?: never;
          phone?: string;
          updated_at?: string;
          user_id?: string | null;
        };
        Relationships: [];
      };
      queue_entries: {
        Row: {
          appointment_id: number | null;
          created_at: string;
          doctor_id: number;
          patient_id: number;
          queue_date: string;
          queue_id: number;
          queue_position: number | null;
          queued_at: string | null;
          status: Database["public"]["Enums"]["queue_status"];
          updated_at: string;
          verified: boolean;
          verified_at: string | null;
          verified_by: number | null;
        };
        Insert: {
          appointment_id?: number | null;
          created_at?: string;
          doctor_id: number;
          patient_id: number;
          queue_date?: string;
          queue_id?: never;
          queue_position?: number | null;
          queued_at?: string | null;
          status?: Database["public"]["Enums"]["queue_status"];
          updated_at?: string;
          verified?: boolean;
          verified_at?: string | null;
          verified_by?: number | null;
        };
        Update: {
          appointment_id?: number | null;
          created_at?: string;
          doctor_id?: number;
          patient_id?: number;
          queue_date?: string;
          queue_id?: never;
          queue_position?: number | null;
          queued_at?: string | null;
          status?: Database["public"]["Enums"]["queue_status"];
          updated_at?: string;
          verified?: boolean;
          verified_at?: string | null;
          verified_by?: number | null;
        };
        Relationships: [
          {
            foreignKeyName: "queue_entries_appointment_id_fkey";
            columns: ["appointment_id"];
            isOneToOne: false;
            referencedRelation: "appointments";
            referencedColumns: ["appointment_id"];
          },
          {
            foreignKeyName: "queue_entries_doctor_id_fkey";
            columns: ["doctor_id"];
            isOneToOne: false;
            referencedRelation: "doctors";
            referencedColumns: ["doctor_id"];
          },
          {
            foreignKeyName: "queue_entries_patient_id_fkey";
            columns: ["patient_id"];
            isOneToOne: false;
            referencedRelation: "patients";
            referencedColumns: ["patient_id"];
          },
          {
            foreignKeyName: "queue_entries_verified_by_fkey";
            columns: ["verified_by"];
            isOneToOne: false;
            referencedRelation: "receptionists";
            referencedColumns: ["receptionist_id"];
          },
        ];
      };
      receptionists: {
        Row: {
          created_at: string;
          email: string;
          name: string;
          receptionist_id: number;
          updated_at: string;
          user_id: string;
        };
        Insert: {
          created_at?: string;
          email: string;
          name: string;
          receptionist_id?: never;
          updated_at?: string;
          user_id: string;
        };
        Update: {
          created_at?: string;
          email?: string;
          name?: string;
          receptionist_id?: never;
          updated_at?: string;
          user_id?: string;
        };
        Relationships: [];
      };
      user_roles: {
        Row: {
          role: Database["public"]["Enums"]["app_role"];
          user_id: string;
        };
        Insert: {
          role: Database["public"]["Enums"]["app_role"];
          user_id: string;
        };
        Update: {
          role?: Database["public"]["Enums"]["app_role"];
          user_id?: string;
        };
        Relationships: [];
      };
    };
    Views: {
      [_ in never]: never;
    };
    Functions: {
      _check_in: { Args: { p_appointment_id: number }; Returns: number };
      _editable_consultation: {
        Args: { p_consultation_id: number; p_text: string };
        Returns: undefined;
      };
      book_appointment: {
        Args: { p_date: string; p_doctor_id: number; p_time: string };
        Returns: number;
      };
      cancel_appointment: {
        Args: { p_appointment_id: number };
        Returns: undefined;
      };
      clinic_now_time: { Args: never; Returns: string };
      clinic_today: { Args: never; Returns: string };
      current_doctor_id: { Args: never; Returns: number };
      current_patient_id: { Args: never; Returns: number };
      current_receptionist_id: { Args: never; Returns: number };
      get_available_slots: {
        Args: { p_date: string; p_doctor_id: number };
        Returns: {
          is_available: boolean;
          slot_time: string;
        }[];
      };
      has_role: {
        Args: { _role: Database["public"]["Enums"]["app_role"]; _uid: string };
        Returns: boolean;
      };
      public_queue_board: {
        Args: never;
        Returns: {
          doctor_id: number;
          doctor_name: string;
          now_serving: number;
          specialization: string;
          waiting_count: number;
        }[];
      };
      recalculate_queue: {
        Args: { p_date: string; p_doctor_id: number };
        Returns: undefined;
      };
      receptionist_check_in_patient: {
        Args: { p_appointment_id: number };
        Returns: number;
      };
      register_walk_in_patient: {
        Args: {
          p_doctor_id: number;
          p_email: string;
          p_name: string;
          p_phone: string;
        };
        Returns: {
          queue_id: number;
          queue_position: number;
        }[];
      };
      request_check_in: { Args: { p_appointment_id: number }; Returns: number };
      save_consultation_notes: {
        Args: { p_consultation_id: number; p_notes: string };
        Returns: undefined;
      };
      save_prescription: {
        Args: { p_consultation_id: number; p_prescription: string };
        Returns: undefined;
      };
      start_consultation: { Args: { p_queue_id: number }; Returns: number };
      update_consultation_status: {
        Args: {
          p_consultation_id: number;
          p_status: Database["public"]["Enums"]["consultation_status"];
        };
        Returns: undefined;
      };
      update_queue_status: {
        Args: {
          p_queue_id: number;
          p_status: Database["public"]["Enums"]["queue_status"];
        };
        Returns: undefined;
      };
      verify_and_add_to_queue: { Args: { p_queue_id: number }; Returns: number };
      verify_consultation_status: {
        Args: { p_consultation_id: number };
        Returns: undefined;
      };
    };
    Enums: {
      app_role: "patient" | "doctor" | "receptionist";
      appointment_status: "booked" | "confirmed" | "checked_in" | "completed" | "cancelled";
      consultation_status: "in_progress" | "completed";
      queue_status: "checkin_requested" | "waiting" | "in_consultation" | "completed" | "cancelled";
    };
    CompositeTypes: {
      [_ in never]: never;
    };
  };
};

type DatabaseWithoutInternals = Omit<Database, "__InternalSupabase">;

type DefaultSchema = DatabaseWithoutInternals[Extract<keyof Database, "public">];

export type Tables<
  DefaultSchemaTableNameOrOptions extends
    | keyof (DefaultSchema["Tables"] & DefaultSchema["Views"])
    | { schema: keyof DatabaseWithoutInternals },
  TableName extends (DefaultSchemaTableNameOrOptions extends {
    schema: keyof DatabaseWithoutInternals;
  }
    ? keyof (DatabaseWithoutInternals[DefaultSchemaTableNameOrOptions["schema"]]["Tables"] &
        DatabaseWithoutInternals[DefaultSchemaTableNameOrOptions["schema"]]["Views"])
    : never) = never,
> = DefaultSchemaTableNameOrOptions extends {
  schema: keyof DatabaseWithoutInternals;
}
  ? (DatabaseWithoutInternals[DefaultSchemaTableNameOrOptions["schema"]]["Tables"] &
      DatabaseWithoutInternals[DefaultSchemaTableNameOrOptions["schema"]]["Views"])[TableName] extends {
      Row: infer R;
    }
    ? R
    : never
  : DefaultSchemaTableNameOrOptions extends keyof (DefaultSchema["Tables"] & DefaultSchema["Views"])
    ? (DefaultSchema["Tables"] & DefaultSchema["Views"])[DefaultSchemaTableNameOrOptions] extends {
        Row: infer R;
      }
      ? R
      : never
    : never;

export type TablesInsert<
  DefaultSchemaTableNameOrOptions extends
    keyof DefaultSchema["Tables"] | { schema: keyof DatabaseWithoutInternals },
  TableName extends (DefaultSchemaTableNameOrOptions extends {
    schema: keyof DatabaseWithoutInternals;
  }
    ? keyof DatabaseWithoutInternals[DefaultSchemaTableNameOrOptions["schema"]]["Tables"]
    : never) = never,
> = DefaultSchemaTableNameOrOptions extends {
  schema: keyof DatabaseWithoutInternals;
}
  ? DatabaseWithoutInternals[DefaultSchemaTableNameOrOptions["schema"]]["Tables"][TableName] extends {
      Insert: infer I;
    }
    ? I
    : never
  : DefaultSchemaTableNameOrOptions extends keyof DefaultSchema["Tables"]
    ? DefaultSchema["Tables"][DefaultSchemaTableNameOrOptions] extends {
        Insert: infer I;
      }
      ? I
      : never
    : never;

export type TablesUpdate<
  DefaultSchemaTableNameOrOptions extends
    keyof DefaultSchema["Tables"] | { schema: keyof DatabaseWithoutInternals },
  TableName extends (DefaultSchemaTableNameOrOptions extends {
    schema: keyof DatabaseWithoutInternals;
  }
    ? keyof DatabaseWithoutInternals[DefaultSchemaTableNameOrOptions["schema"]]["Tables"]
    : never) = never,
> = DefaultSchemaTableNameOrOptions extends {
  schema: keyof DatabaseWithoutInternals;
}
  ? DatabaseWithoutInternals[DefaultSchemaTableNameOrOptions["schema"]]["Tables"][TableName] extends {
      Update: infer U;
    }
    ? U
    : never
  : DefaultSchemaTableNameOrOptions extends keyof DefaultSchema["Tables"]
    ? DefaultSchema["Tables"][DefaultSchemaTableNameOrOptions] extends {
        Update: infer U;
      }
      ? U
      : never
    : never;

export type Enums<
  DefaultSchemaEnumNameOrOptions extends
    keyof DefaultSchema["Enums"] | { schema: keyof DatabaseWithoutInternals },
  EnumName extends (DefaultSchemaEnumNameOrOptions extends {
    schema: keyof DatabaseWithoutInternals;
  }
    ? keyof DatabaseWithoutInternals[DefaultSchemaEnumNameOrOptions["schema"]]["Enums"]
    : never) = never,
> = DefaultSchemaEnumNameOrOptions extends {
  schema: keyof DatabaseWithoutInternals;
}
  ? DatabaseWithoutInternals[DefaultSchemaEnumNameOrOptions["schema"]]["Enums"][EnumName]
  : DefaultSchemaEnumNameOrOptions extends keyof DefaultSchema["Enums"]
    ? DefaultSchema["Enums"][DefaultSchemaEnumNameOrOptions]
    : never;

export type CompositeTypes<
  PublicCompositeTypeNameOrOptions extends
    keyof DefaultSchema["CompositeTypes"] | { schema: keyof DatabaseWithoutInternals },
  CompositeTypeName extends (PublicCompositeTypeNameOrOptions extends {
    schema: keyof DatabaseWithoutInternals;
  }
    ? keyof DatabaseWithoutInternals[PublicCompositeTypeNameOrOptions["schema"]]["CompositeTypes"]
    : never) = never,
> = PublicCompositeTypeNameOrOptions extends {
  schema: keyof DatabaseWithoutInternals;
}
  ? DatabaseWithoutInternals[PublicCompositeTypeNameOrOptions["schema"]]["CompositeTypes"][CompositeTypeName]
  : PublicCompositeTypeNameOrOptions extends keyof DefaultSchema["CompositeTypes"]
    ? DefaultSchema["CompositeTypes"][PublicCompositeTypeNameOrOptions]
    : never;

export const Constants = {
  public: {
    Enums: {
      app_role: ["patient", "doctor", "receptionist"],
      appointment_status: ["booked", "confirmed", "checked_in", "completed", "cancelled"],
      consultation_status: ["in_progress", "completed"],
      queue_status: ["checkin_requested", "waiting", "in_consultation", "completed", "cancelled"],
    },
  },
} as const;
