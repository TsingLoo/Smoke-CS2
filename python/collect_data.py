import csv
import sys

OUTPUT_FILE = "merged_data.csv"
# 128 * 128 = 16384 rows per batch
BATCH_SIZE = 128 * 128


def save_batch(data, batch_num):
    """Helper function to append data to CSV"""
    try:
        with open(OUTPUT_FILE, "a", newline="", encoding="utf-8") as f:
            writer = csv.writer(f)
            writer.writerows(data)
        print(f"   [Saved] Batch #{batch_num} ({len(data)} rows) written to disk.")
    except Exception as e:
        print(f"   [Error] Failed to save batch: {e}")


def main():
    print(f"--- Large Data Collector ---")
    print(f"Target File: {OUTPUT_FILE}")
    print(f"Batch Size : {BATCH_SIZE} rows (128 * 128)")
    print("-" * 40)
    print("Ready for input. Paste data or pipe from file...")
    print("1. Auto-saves every 16,384 valid lines.")
    print("2. Press Ctrl+C to stop.")
    print("-" * 40)

    buffer = []
    total_batches = 0

    try:
        # Continuous reading loop
        for line in sys.stdin:
            line = line.strip()
            if not line:
                continue

            parts = line.split()

            if len(parts) == 4:
                buffer.append(parts)
                current_count = len(buffer)

                # Optional: Progress indicator every 1000 lines so you know it's working
                if current_count % 1000 == 0:
                    print(
                        f"   ... buffering: {current_count}/{BATCH_SIZE} lines",
                        end="\r",
                    )

                # Check if we reached the batch size
                if current_count == BATCH_SIZE:
                    total_batches += 1
                    print(f"\n> Batch limit reached ({BATCH_SIZE}). Saving...")

                    save_batch(buffer, total_batches)

                    print(f"> STATUS: {total_batches} full batches collected so far.")
                    print(f"> Waiting for next batch...")
                    print("-" * 20)

                    # Clear buffer for the next batch
                    buffer = []
            else:
                # Silent warning for performance, or uncomment to see errors
                # print(f"[Warning] Ignored invalid line: {line}")
                pass

    except KeyboardInterrupt:
        print("\n\n--- Stopping ---")
        # Check if there is unsaved data remaining
        if buffer:
            print(
                f"Warning: You have {len(buffer)} unsaved lines in memory (Batch incomplete)."
            )
            choice = input("Save remaining lines? (y/n): ").strip().lower()
            if choice == "y":
                save_batch(buffer, "FINAL_PARTIAL")

        print(f"Total full batches completed: {total_batches}")
        print("Exiting.")


if __name__ == "__main__":
    main()
